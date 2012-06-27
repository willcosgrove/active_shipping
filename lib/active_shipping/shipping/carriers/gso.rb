module ActiveMerchant
  module Shipping
    class GSO < Carrier
      include HTTParty
      format :xml
      headers 'Content-Type' => 'text/xml;charset=UTF-8', "User-Agent" => '485.13.9 Darwin/11.0.0'
      cattr_reader :name
      @@name = "Golden State Overnight"
      
      SERVICE_TYPES = {
        "PDS" => "GSO Priority Overnight",
        "EPS" => "GSO Early Priority Overnight",
        "NPS" => "GSO Noon Priority",
        "SDS" => "GSO Saturday Delivery",
        "ESS" => "GSO Early Saturday",
        "CPS" => "GSO Ground"
      }
      
      def find_rates(origin, destination, packages, options = {})
        origin = Location.from(origin)
        destination = Location.from(destination)
        packages = Array(packages)
        self.class.headers 'SOAPAction' => 'http://gso.com/GsoShipWS/GetShippingRatesAndTimes'
        responses = packages.collect do |package|
          builder = Builder::XmlMarkup.new
          body = builder.tag!("soapenv:Envelope", {"xmlns:soapenv" => "http://schemas.xmlsoap.org/soap/envelope/", "xmlns:gsos" => "http://gso.com/GsoShipWS"}) { |b|
            b.tag!("soapenv:Header") {
              b.tag!("gsos:AuthenticationHeader") {
                b.gsos :UserName, @options[:username]
                b.gsos :Password, @options[:password]
              }
            }
            b.tag!("soapenv:Body") {
              b.tag!("gsos:GetShippingRatesAndTimes") {
                b.tag!("gsos:GetShippingRatesAndTimesRequest") {
                  b.gsos :AccountNumber, @options[:account_number]
                  b.gsos :OriginZip, origin.postal_code
                  b.gsos :DestinationZip, destination.postal_code
                  b.gsos :PackageWeight, package.pounds
                }
              }
            }
          }
          response = self.class.post("http://wsa.gso.com/gsoshipws1.0/gsoshipws.asmx", body: body)
          [package, response]
        end
        rate_estimates = parse_rates_responses(origin, destination, packages, responses, options)
        RateResponse.new(true, "200", {}, rate_estimates: rate_estimates)
      end

      def find_tracking_info(tracking_number, options={})

      end

      def requirements
        [:username, :password, :account_number]
      end

      private

      def parse_rates_responses(origin, destination, packages, responses, options={})
        deilvery_services = responses.first[1]["Envelope"]["Body"]["GetShippingRatesAndTimesResponse"]["GetShippingRatesAndTimesResult"]["DeliveryServices"]
        delivery_services.collect do |delivery_service|
          package_rates = responses.collect { |response| {package: response[0], rate: response["ShipmentCharges"]["TotalCharge"] } }
          RateEstimate.new(origin, destination, @@name, delivery_service["ServiceDescription"], {
            service_code: delivery_service["ServiceCode"],
            package_rates: package_rates,
            currency: 'USD',
            delivery_range: [Date.strptime(delivery_service["GuaranteedDeliveryDateTime"], "%Y-%m-%dT%H:%M:%S")] * 2
          })
        end
      end
      
    end
  end
end
