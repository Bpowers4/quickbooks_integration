module QBIntegration
  module Service
    class Vendor < Base
      attr_reader :vendor

      def initialize(config, payload)
        @vendor = payload[:vendor]
        super("Vendor", config)
      end

      def find_by_id(id)
        util = Quickbooks::Util::QueryBuilder.new
        clause = util.clause("id", "=", id)
        vendor = @quickbooks.query("select * from Vendor where #{clause}").entries.first
        raise "No Vendor '#{name}' defined in service" unless vendor
        vendor
      end

      def all(date, page = 1, per_page = 25)
        total = @quickbooks.all.count
        util = Quickbooks::Util::QueryBuilder.new
        clause = util.clause("Metadata.LastUpdatedTime", ">", date)
        vendors = @quickbooks.query("select * from Vendor where #{clause}", page: page, per_page: per_page)
        {
          vendors: vendors,
          total: total
        }
      end

      def create
        new_vendor = create_model
        build new_vendor
        @quickbooks.create new_vendor
      end

      def find_by_name(name)
        util = Quickbooks::Util::QueryBuilder.new
        clause = util.clause("CompanyName", "=", name)
        vendor = @quickbooks.query("select * from Vendor where #{clause}").entries.first
        raise "No Vendor '#{name}' defined in service" unless vendor
        vendor
      end

      private

      def build(new_vendor)
        new_vendor.title = vendor["sysid"]
        new_vendor.display_name = vendor["name"]
        new_vendor.company_name = vendor["name"]
        new_vendor.primary_phone = Phone.build(vendor["phone"])
        new_vendor.primary_email_address = Email.build(vendor["email"])
        new_vendor.billing_address = Address.build({
          "address1" => vendor["street1"],
          "address2" => vendor["street2"],
          "city" => vendor["city"],
          "country" => vendor["country"],
          "city" => vendor["city"],
          "state" => vendor["state"],
          "zipcode" => vendor["zipcode"],
        })
      end
    end
  end
end
