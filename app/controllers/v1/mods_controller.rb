module V1
  class ModsController < ApplicationController
    skip_forgery_protection # No need for forgery protection on an API

    # Given a POST body with cocina, transform it to MODS xml. Used by Argo to preview metadata
    def create
      public_cocina = Cocina::Models.build(params[:mods].to_unsafe_h)
      desc_metadata_service = Publish::PublicDescMetadataService.new(public_cocina, [])
      desc_md_xml = desc_metadata_service.ng_xml(include_access_conditions: false)
      render xml: desc_md_xml.to_xml
    end
  end
end
