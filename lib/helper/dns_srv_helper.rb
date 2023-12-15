# frozen_string_literal: true

require "resolv"

module DiscourseAi
  module Helper
    module DnsSrvHelper
      def self.dns_srv_lookup(domain)
        Discourse
          .cache
          .fetch("dns_srv_lookup:#{domain}", expires_in: 5.minutes) do
            resources = dns_srv_lookup_for_domain(domain)

            select_server(resources)
          end
      end

      private

      def self.dns_srv_lookup_for_domain(domain)
        resolver = Resolv::DNS.new
        resources = resolver.getresources(domain, Resolv::DNS::Resource::IN::SRV)
      end

      def self.select_server(resources)
        priority = resources.group_by(&:priority).keys.min

        priority_resources = resources.select { |r| r.priority == priority }

        total_weight = priority_resources.map(&:weight).sum

        random_weight = rand(total_weight)

        priority_resources.each do |resource|
          random_weight -= resource.weight

          return resource if random_weight < 0
        end

        # fallback
        resources.first
      end
    end
  end
end
