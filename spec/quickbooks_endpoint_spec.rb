require 'spec_helper'

describe QuickbooksEndpoint do
  def parameters
    { 
      'quickbooks_access_token' => "123",
      'quickbooks_access_secret' => "OLDrgtlzvffzyH1hMDtW5PF6exayVlaCDxFjMd0o",
      'quickbooks_realm' => "1081126165",
      "quickbooks_deposit_to_account_name" => "Undeposited Funds",
      "quickbooks_payment_method_name" => [
        {
          "master" => "MasterCard",
          "visa" => "Visa",
          "american_express" => "AmEx",
          "discover" => "Discover",
          "PayPal" => "PayPal"
        }
      ],
      "quickbooks_shipping_item" => "Shipping Charges",
      "quickbooks_tax_item" => "State Sales Tax-NY",
      "quickbooks_discount_item" => "Discount",
      "quickbooks_account_name" => "Inventory Asset",
      "quickbooks_web_orders_user" => "false"
    }
  end

  describe "order sync" do
    let(:message) {
      {
        "order" => Factories.order,
        "parameters" => parameters
      }.with_indifferent_access
    }

    context "new sales receipt" do
      context "persist new sales receipt" do
        it "generates a json response with an info notification" do
          # change order number in case you want to persist a new order
          message[:order][:number] = "R45245242545"
          message[:order][:placed_on] = "2013-12-18 14:51:18 -0300"

          VCR.use_cassette("sales_receipt/sync_order_sales_receipt_post", match_requests_on: [:body, :method]) do
            post '/orders', message.to_json, auth

            response = JSON.parse(last_response.body)
            response["notifications"].first["subject"].should match "Created Quickbooks Sales Receipt"
          end
        end
      end
    end

    context "existing sales receipt with order:updated" do
      before { message[:message] = "order:updated" }

      it "updates sales receipt just fine" do
        VCR.use_cassette("sales_receipt/sync_updated_order_post", match_requests_on: [:body, :method]) do
          post '/orders', message.to_json, auth
          last_response.status.should eql 200

          response = JSON.parse(last_response.body)
          response["message_id"].should eql "abc"
          response["notifications"].first["subject"].should match "Updated Quickbooks Sales Receipt"
        end
      end
    end

    context "order canceled" do
      before do
        message[:message] = "order:canceled"
        order = Factories.new_credit_memo
        message[:payload][:order] = order[:order]
      end

      it "generates a json response with an info notification" do
        VCR.use_cassette("credit_memo/create_from_receipt", match_requests_on: [:body, :method]) do
          post '/orders', message.to_json, auth
          last_response.status.should eql 200

          response = JSON.parse(last_response.body)
          response["message_id"].should eql "abc"
          response["notifications"].first["subject"].should match "Created Quickbooks Credit Memo"
        end
      end
    end
  end

  describe "return authorizations" do
    let(:message) do
      {
        message: "return_authorization:new",
        message_id: "abc",
        payload: {
          return_authorization: Factories.return_authorization,
          original: Factories.return_authorization,
          parameters: parameters
        }
      }.with_indifferent_access
    end

    it "generates a json response with an info notification" do
      VCR.use_cassette("credit_memo/create_from_return", match_requests_on: [:method, :body]) do
        post '/returns', message.to_json, auth
        response = JSON.parse(last_response.body)
        response["notifications"].first["subject"].should match "Created Quickbooks Credit Memo"
      end
    end

    it "returns 500 if order return was not sync yet" do
      message[:payload][:return_authorization][:order][:number] = "imnotthereatall"

      VCR.use_cassette("credit_memo/return_authorization_non_sync_order", match_requests_on: [:body, :method]) do
        post '/returns', message.to_json, auth
        last_response.status.should eql 500
        response = JSON.parse(last_response.body)
        response["notifications"].first["subject"].should match "Received return for order not sync"
      end
    end

    context "update" do
      before { message[:message] = "return_authorization:updated" }

      it "updates existing return just fine" do
        VCR.use_cassette("credit_memo/sync_return_authorization_updated", match_requests_on: [:body, :method]) do
          post '/returns', message.to_json, auth
          last_response.status.should eql 200
          response = JSON.parse(last_response.body)
          response["notifications"].first["subject"].should match "Updated Quickbooks Credit Memo"
        end
      end
    end
  end

  context "monitor stock" do
    let(:message) do
      {
        :message_id => "abc",
        :payload => { "sku" => "4553254352", "parameters" => parameters }
      }.with_indifferent_access
    end

    it "returns message with item quantity" do
      VCR.use_cassette("item/find_item_track_inventory", match_requests_on: [:body, :method]) do
        post '/monitor_stock', message.to_json, auth

        last_response.status.should eql 200
        response = JSON.parse(last_response.body).with_indifferent_access
        message = response[:messages].first
        expect(message[:payload][:quantity]).to eq 56
      end
    end

    it "just 200 if item not found" do
      message[:payload][:sku] = "imreallynothere"

      VCR.use_cassette("item/item_not_found", match_requests_on: [:body, :method]) do
        post '/monitor_stock', message.to_json, auth
        last_response.status.should eql 200
      end
    end
  end
end
