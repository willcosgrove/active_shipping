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
        packages.collect do |package|
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
          parse_rates_response(origin, destination, packages, response, options)
        end
      end

      def find_tracking_info(tracking_number, options={})

      end

      def requirements
        [:username, :password, :account_number]
      end

      private

      def parse_rates_response(origin, destination, packages, response, options={})
        rate_estimates = response["Envelope"]["Body"]["GetShippingRatesAndTimesResponse"]["GetShippingRatesAndTimesResult"]["DeliveryServices"].collect do |delivery_service|
          RateEstimate.new()
          # [delivery_service["ServiceDescription"], (delivery_service["ShipmentCharges"]["TotalCharge"].to_f * 100).to_i]
        end
      end
      
    end
  end
end
