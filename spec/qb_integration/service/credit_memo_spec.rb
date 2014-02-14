require 'spec_helper'

module QBIntegration
  module Service
    describe CreditMemo do
      let(:config) do
        {
          'quickbooks.realm' => "1014843225",
          'quickbooks.access_token' => "qyprdINz6x1Qccyyj7XjELX7qxFBE9CSTeNLmbPYb7oMoktC",
          'quickbooks.access_secret' => "wiCLZbYVDH94UgmJDdDWxpYFG2CAh30v0sOjOsDX",
          "quickbooks.payment_method_name" => [{ "visa" => "Discover" }],
          'quickbooks.account_name' => "Inventory Asset",
          "quickbooks.shipping_item" => "Shipping Charges",
          "quickbooks.tax_item" => "State Sales Tax-NY",
          "quickbooks.discount_item" => "Discount"
        }
      end

      subject { CreditMemo.new(config, payload) }

      context "order message" do
        let(:payload) do
          {
            "order" => Factories.order,
            "original" => Factories.original
          }.with_indifferent_access
        end

        it "creates from sales receipt" do
          payload[:order][:number] = "R518606166"
          payload[:order][:totals][:order] = "125.70"

          VCR.use_cassette("credit_memo/create_from_receipt") do
            sales_receipt = Service::SalesReceipt.new(config, payload).find_by_order_number
            credit_memo = subject.create_from_receipt sales_receipt
            expect(credit_memo.doc_number).to eq sales_receipt.doc_number
          end
        end
      end

      context "return authorization message" do
        let(:payload) do
          {
            return_authorization: Factories.return_authorization,
            order: Factories.return_authorization["order"],
            original: Factories.return_authorization
          }.with_indifferent_access
        end

        it "creates credit memo given payload and sales receipt" do
          VCR.use_cassette("credit_memo/create_from_return") do
            sales_receipt = Service::SalesReceipt.new(config, payload, dependencies: false).find_by_order_number
            credit_memo = subject.create_from_return Factories.return_authorization, sales_receipt
          end
        end

        it "updates credit memo given payload and sales receipt" do
          VCR.use_cassette("credit_memo/updates_from_return") do
            sales_receipt = Service::SalesReceipt.new(config, payload, dependencies: false).find_by_order_number

            credit_memo = subject.find_by_number Factories.return_authorization["number"]
            sales_receipt.email = "creditmemo_updated@quickbooks.com"
            credit_memo_updated = subject.update credit_memo, Factories.return_authorization, sales_receipt
            expect(credit_memo_updated.bill_email.address).to eq "creditmemo_updated@quickbooks.com"
          end
        end
      end
    end
  end
end