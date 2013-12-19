require 'spec_helper'

describe QuickbooksEndpoint do
  def auth
    {'HTTP_X_AUGURY_TOKEN' => 'x123'}
  end

  def parameters
    [
      {:name => 'quickbooks.access_token', :value => "qyprdINz6x1Qccyyj7XjELX7qxFBE9CSTeNLmbPYb7oMoktC" },
      {:name => 'quickbooks.access_secret', :value => "wiCLZbYVDH94UgmJDdDWxpYFG2CAh30v0sOjOsDX" },
      {:name => 'quickbooks.realm', :value => "1014843225" },
      {:name => "quickbooks.deposit_to_account_name", :value => "Undeposited Funds"},
      {:name => "quickbooks.payment_method_name", :value => [
        {
          "master" => "MasterCard",
          "visa" => "Visa",
          "american_express" => "AmEx",
          "discover" => "Discover",
          "PayPal" => "PayPal"
        }]
      },
      {:name => "quickbooks.shipping_item", :value => "Shipping Charges"},
      {:name => "quickbooks.tax_item", :value => "State Sales Tax-NY"},
      {:name => "quickbooks.coupon_item", :value => "Coupons"},
      {:name => "quickbooks.discount_item", :value => "Discount"},
      {:name => "quickbooks.account_name", :value => "Inventory Asset"},
      {:name => "quickbooks.timezone", :value => "EST"}
    ]
  end

  describe "order sync" do
    let(:message) {
      {
        :message_id => "abc",
        :payload => {
          "order" => Factories.order,
          "original" => Factories.original,
          "parameters" => parameters
        }
      }.with_indifferent_access
    }

    context "new sales receipt" do
      shared_context "persist new sales receipt" do
        it "generates a json response with an info notification" do
          # change order number in case you want to persist a new order
          message[:payload][:order][:number] = "R4435534534"
          message[:payload][:order][:placed_on] = "2013-12-18 14:51:18 -0300"

          VCR.use_cassette("sales_receipt/sync_order_sales_receipt_post") do
            post '/order_persist', message.to_json, auth
            last_response.status.should eql 200

            response = JSON.parse(last_response.body)
            response["message_id"].should eql "abc"
            response["notifications"].first["subject"].should match "Created Quickbooks sales receipt"
          end
        end
      end

      context "with order:new" do
        before { message[:message] = "order:new" }
        include_context "persist new sales receipt"
      end

      context "with order:updated" do
        before { message[:message] = "order:updated" }
        include_context "persist new sales receipt"
      end
    end

    context "order canceled" do
      before { message[:message] = "order:canceled" }

      it "generates a json response with an info notification" do
        # change order number in case you want to persist a credit memo
        message[:payload][:order][:number] = "R4435534534"

        VCR.use_cassette("credit_memo/sync_order_credit_memo_post") do
          post '/order_persist', message.to_json, auth
          last_response.status.should eql 200

          response = JSON.parse(last_response.body)
          response["message_id"].should eql "abc"
          response["notifications"].first["subject"].should match "Created Quickbooks credit memo"
        end
      end
    end
  end

  describe "return authorizations" do
    let(:message) {
      {
        message: "return_authorization:new",
        message_id: "abc",
        payload: {
          return_authorization: {
            order: { number: Factories.order["number"] }
          },
          "parameters" => parameters
        }
      }.with_indifferent_access
    }

    it "generates a json response with an info notification" do
      VCR.use_cassette("credit_memo/sync_return_authorization_new") do
        post '/return_authorization_persist', message.to_json, auth
        last_response.status.should eql 200
      end
    end
  end
end
