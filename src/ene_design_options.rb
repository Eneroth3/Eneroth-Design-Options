# frozen_string_literal: true

require "extensions"

# Eneroth Extensions
module Eneroth
  # Eneroth Design Options
  module DesignOptions
    path = __FILE__.dup
    path.force_encoding("UTF-8") if path.respond_to?(:force_encoding)

    # Identifier for this extension.
    PLUGIN_ID = File.basename(path, ".*")

    # Root directory of this extension.
    PLUGIN_ROOT = File.join(File.dirname(path), PLUGIN_ID)

    # Extension object for this extension.
    EXTENSION = SketchupExtension.new(
      "Eneroth Design Options",
      File.join(PLUGIN_ROOT, "main")
    )

    EXTENSION.creator     = "Eneroth"
    EXTENSION.description =
      "Manage visibility of mutually exclusive design options."
    EXTENSION.version     = "1.0.0"
    EXTENSION.copyright   = "2025, #{EXTENSION.creator}"
    Sketchup.register_extension(EXTENSION, true)
  end
end
