require_relative 'spec_helper'

describe 'App' do
  let(:realm) { ENV['quickbooks_realm'] }
  let(:secret) { ENV['quickbooks_access_secret'] }
  let(:token) { ENV['quickbooks_access_token'] }
  let(:headers) {
    {
      "Content-Type": "application/json"
    }
  }


  include Rack::Test::Methods

  def app
    QuickbooksEndpoint
  end

  describe "#add_bill_purchase_order", vcr: true do
    it "returns 500 when creating a bill without received_items" do
      payload = {
        id: "1013",
        line_items: [
          name: "Battery Wall Mirror",
          price: 35.0,
          product: {
            "name": "Battery Wall Mirror",
            "sysid": 1185,
          },
          quantity: 1,
          systum_id: 2044,
          product_id: "SWS03",
          discount_value: 0.0
        ],
        received_items: [
        ]
      }

      post '/add_bill_to_purchase_order', {
        "request_id": "25d4847a-a9ba-4b1f-9ab1-7faa861a4e67",
        "parameters": {
          "quickbooks_realm": realm,
          "quickbooks_access_token": token,
          "quickbooks_access_secret": secret,
        },
        "purchase_order": payload
      }.to_json, headers
      data = JSON.parse(last_response.body)
      expect(last_response.status).to eq 500
    end

    it "returns 500 when creating a bill with same received_items and quantity_received_in_qbo" do
      payload = {
        id: "1013",
        line_items: [
          name: "Battery Wall Mirror",
          price: 35.0,
          product: {
            "name": "Battery Wall Mirror",
            "sysid": 1185,
          },
          quantity: 1,
          systum_id: 2044,
          product_id: "SWS03",
          discount_value: 0.0
        ],
        received_items: [
          {
            "quantity" => 24,
            "sku" => "Battery Wall Mirror"
          }
        ],
        quantity_received_in_qbo: [
          {
            "sku" => "Battery Wall Mirror",
            "quantity" => 24
          }
        ]
      }

      post '/add_bill_to_purchase_order', {
        "request_id": "25d4847a-a9ba-4b1f-9ab1-7faa861a4e67",
        "parameters": {
          "quickbooks_realm": realm,
          "quickbooks_access_token": token,
          "quickbooks_access_secret": secret,
        },
        "purchase_order": payload
      }.to_json, headers
      data = JSON.parse(last_response.body)
      expect(last_response.status).to eq 500
    end

    it "returns 200 when creating a new bill" do
      payload = {
        id: "1013",
        line_items: [
          name: "Battery Wall Mirror",
          price: 35.0,
          product: {
            "name": "Battery Wall Mirror",
            "sysid": 1185,
          },
          quantity: 1,
          systum_id: 2044,
          product_id: "SWS03",
          discount_value: 0.0
        ],
        received_items: [
          {
            quantity: 24,
            sku: "Battery Wall Mirror"
          }
        ]
      }

      expected_po = {
        id: "1013",
        received_items: [
          {
            "quantity" => 24,
            "sku" => "Battery Wall Mirror"
          }
        ],
        quantity_received_in_qbo: [
          {
            "sku" => "Battery Wall Mirror",
            "quantity" => 24
          }
        ]
      }
      post '/add_bill_to_purchase_order', {
        "request_id": "25d4847a-a9ba-4b1f-9ab1-7faa861a4e67",
        "parameters": {
          "quickbooks_realm": realm,
          "quickbooks_access_token": token,
          "quickbooks_access_secret": secret,
        },
        "purchase_order": payload
      }.to_json, headers
      data = JSON.parse(last_response.body)
      expect(last_response.status).to eq 200
      expect(data["purchase_orders"][0]["received_items"]).to eq expected_po[:received_items]
      expect(data["purchase_orders"][0]["quantity_received_in_qbo"][0]).to eq expected_po[:quantity_received_in_qbo][0]
      expect(data["bills"][0]["balance"]).to eq 192
    end

    it "returns bill of 16 when received_so_far is 22 and quantity_received is 24" do
      payload = {
        id: "1013",
        line_items: [
          name: "Battery Wall Mirror",
          price: 8.0,
          product: {
            "name": "Battery Wall Mirror",
            "sysid": 1185,
          },
          quantity: 1,
          systum_id: 2044,
          product_id: "SWS03",
          discount_value: 0.0
        ],
        received_items: [
          {
            quantity: 24,
            sku: "Battery Wall Mirror"
          }
        ],
        quantity_received_in_qbo: [
          {
            sku: "Battery Wall Mirror",
            quantity: 22
          }
        ]
      }

      expected_po = {
        id: "1013",
        received_items: [
          {
            "quantity" => 24,
            "sku" => "Battery Wall Mirror"
          }
        ],
        quantity_received_in_qbo: [
          {
            "sku" => "Battery Wall Mirror",
            "quantity" => 24
          }
        ]
      }
      post '/add_bill_to_purchase_order', {
        "request_id": "25d4847a-a9ba-4b1f-9ab1-7faa861a4e67",
        "parameters": {
          "quickbooks_realm": realm,
          "quickbooks_access_token": token,
          "quickbooks_access_secret": secret,
        },
        "purchase_order": payload
      }.to_json, headers
      data = JSON.parse(last_response.body)
      expect(last_response.status).to eq 200
      expect(data["bills"][0]["balance"]).to eq 16
      expect(data["purchase_orders"][0]["received_items"]).to eq expected_po[:received_items]
      expect(data["purchase_orders"][0]["quantity_received_in_qbo"][0]).to eq expected_po[:quantity_received_in_qbo][0]
    end

  end
end
