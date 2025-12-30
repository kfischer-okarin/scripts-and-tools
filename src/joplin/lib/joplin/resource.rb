# frozen_string_literal: true

module Joplin
  PROFILE_DIR = File.expand_path("~/.config/joplin-desktop")

  # Matches Joplin's mime.toFileExtension() which prefers 3-char extensions
  MIME_TO_EXT = {
    "image/jpeg" => "jpg",
    "image/png" => "png",
    "image/gif" => "gif",
    "image/webp" => "webp",
    "image/svg+xml" => "svg",
    "image/bmp" => "bmp",
    "image/tiff" => "tif",
    "application/pdf" => "pdf",
    "text/plain" => "txt",
    "text/html" => "htm",
    "application/json" => "json"
  }.freeze

  Resource = Data.define(:id, :file_extension, :mime) do
    def path
      ext = file_extension.to_s.empty? ? mime_to_ext : file_extension
      File.join(PROFILE_DIR, "resources", "#{id}.#{ext}")
    end

    private

    def mime_to_ext
      MIME_TO_EXT[mime] || mime.to_s.split("/").last.to_s[0, 3]
    end
  end
end
