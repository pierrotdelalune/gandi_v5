# frozen_string_literal: true

class GandiV5
  class LiveDNS
    # A zone within the LiveDNS system.
    # Zones can be used by any number of domains.
    # @!attribute [r] uuid
    #   @return [String]
    # @!attribute [r] name
    #   @return [String]
    # @!attribute [r] sharing_uuid
    #   @return [String]
    # @!attribute [r] soa_retry
    #   @return [Integer] retry period, as reported in SOA record.
    # @!attribute [r] soa_minimum
    #   @return [Integer] minimum and negative TTL, as reported in SOA record.
    # @!attribute [r] soa_refresh
    #   @return [Integer] refresh period, as reported in SOA record.
    # @!attribute [r] soa_expire
    #   @return [Integer] expire period, as reported in SOA record.
    # @!attribute [r] soa_serial
    #   @return [Integer] serial number, as reported in SOA record.
    # @!attribute [r] soa_email
    #   @return [String] admin email address, as reported in SOA record.
    # @!attribute [r] soa_primary_ns
    #   @return [String] primary name server, as reported in SOA record.
    class Zone
      include GandiV5::Data
      include GandiV5::LiveDNS::HasZoneRecords

      members :uuid, :name
      member :sharing_uuid, gandi_key: 'sharing_id'
      member :soa_retry, gandi_key: 'retry'
      member :soa_minimum, gandi_key: 'minimum'
      member :soa_refresh, gandi_key: 'refresh'
      member :soa_expire, gandi_key: 'expire'
      member :soa_serial, gandi_key: 'serial'
      member :soa_email, gandi_key: 'email'
      member :soa_primary_ns, gandi_key: 'primary_ns'

      alias zone_uuid uuid

      # Generate SOA record for the zone
      # @return [String]
      def to_s
        "@\tIN\tSOA\t#{soa_primary_ns} #{soa_email} (\n" \
        "\t#{soa_serial}\t;Serial\n" \
        "\t#{soa_refresh}\t\t;Refresh\n" \
        "\t#{soa_retry}\t\t;Retry\n" \
        "\t#{soa_expire}\t\t;Expire\n" \
        "\t#{soa_minimum}\t\t;Minimum & Negative TTL\n" \
        ')'
      end

      # List the domains that use this zone.
      # @return [Array<String>] The FQDNs.
      # @raise [GandiV5::Error::GandiError] if Gandi returns an error.
      def list_domains
        _response, data = GandiV5.get "#{url}/domains"
        data.map { |item| item['fqdn'] }
      end

      # Attach domain to this zone.
      # @param fqdn [String, #fqdn, #to_s] the fully qualified domain name
      #   that should start using this zone.
      # @return [String] The confirmation message from Gandi.
      # @raise [GandiV5::Error::GandiError] if Gandi returns an error.
      def attach_domain(fqdn)
        fqdn = fqdn.fqdn if fqdn.respond_to?(:fqdn)
        _resp, data = GandiV5.patch "#{BASE}domains/#{CGI.escape fqdn}", { zone_uuid: uuid }.to_json
        data['message']
      end

      # Get snapshot UUIDs for this zone from Gandi.
      # @return [Hash{String => Time}] Mapping snapshot UUID to time made.
      # @raise [GandiV5::Error::GandiError] if Gandi returns an error.
      def snapshots
        GandiV5::LiveDNS::Zone::Snapshot.list uuid
      end

      # Get snapshot from Gandi.
      # @param uuid [String] the UUID of the snapshot to fetch.
      # @return [GandiV5::LiveDNS::Zone::Snapshot]
      # @raise [GandiV5::Error::GandiError] if Gandi returns an error.
      def snapshot(uuid)
        GandiV5::LiveDNS::Zone::Snapshot.fetch self.uuid, uuid
      end

      # Take a snapshot of this zone.
      # @return [GandiV5::LiveDNS::Zone::Snapshot]
      # @raise [GandiV5::Error::GandiError] if Gandi returns an error.
      def take_snapshot
        _response, data = GandiV5.post "#{url}/snapshots"
        snapshot data['uuid']
      end

      # Update this zone.
      # @param name [String, #to_s] new name for the zone.
      # @return [String] The confirmation message from Gandi.
      # @raise [GandiV5::Error::GandiError] if Gandi returns an error.
      def update(name:)
        _response, data = GandiV5.patch url, { name: name }.to_json
        self.name = name
        data['message']
      end

      # Delete this zone from Gandi.
      # @return [nil]
      # @raise [GandiV5::Error::GandiError] if Gandi returns an error.
      def delete
        GandiV5.delete url
      end

      # Create a new zone.
      # @param name [String] the name for the created zone.
      # @param sharing_id [String] the UUID of the account to ceate the zone under.
      # @return [GandiV5::LiveDNS::Zone] The created zone.
      # @raise [GandiV5::Error::GandiError] if Gandi returns an error.
      def self.create(name, sharing_id: nil)
        params = sharing_id ? { sharing_id: sharing_id } : {}

        response, _data = GandiV5.post(
          url,
          { name: name }.to_json,
          params: params
        )

        fetch response.headers[:location].split('/').last
      end

      # List the zones.
      # @return [Array<GandiV5::LiveDNS::Zone>]
      # @raise [GandiV5::Error::GandiError] if Gandi returns an error.
      def self.list
        _response, data = GandiV5.get url
        data.map { |item| from_gandi item }
      end

      # Get a zone from Gandi.
      # @param uuid [String, #to_s] the UUID of the zone to fetch.
      # @return [GandiV5::LiveDNS::Zone]
      # @raise [GandiV5::Error::GandiError] if Gandi returns an error.
      def self.fetch(uuid)
        _response, data = GandiV5.get url(uuid)
        from_gandi data
      end

      private

      def url
        "#{BASE}zones/#{CGI.escape uuid}"
      end

      def self.url(uuid = nil)
        BASE + (uuid ? "zones/#{CGI.escape(uuid)}" : 'zones')
      end
      private_class_method :url
    end
  end
end
