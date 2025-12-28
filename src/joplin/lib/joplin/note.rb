# frozen_string_literal: true

module Joplin
  Note = Data.define(:id, :title, :parent_id, :body, :created_time, :updated_time, :source_url) do
    def initialize(id:, title:, parent_id: nil, body: nil, created_time: nil, updated_time: nil, source_url: nil)
      super
    end
  end
end
