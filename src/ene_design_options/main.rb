# frozen_string_literal: true

module Eneroth
  module DesignOptions
    # Represents a set of (usually) mutually exclusive tags (later also groups?)
    # typically representing different alternatives to a design.
    class OptionsGroup
      # Try to create an OptionsGroup from a tag (layer).
      #
      # Tag name must be prefixed with `"Option {option_name}: "` and there must be
      # other tags following the same pattern, e.g. "Option Fireplace: Rustic",
      # "Option Fireplace: Scandi", "Option Fireplace: Farmhouse" and so on.
      #
      # @param [Sketchup::Layer] tag
      #
      # @return [OptionsGroup, nil]
      #   nil if the tag does not represent a design option.
      def self.from_tag(tag)
        pattern = /Option ([^:]+): ?(.+)/ # Be forgiving about space after colon
        matches = tag.name.match(pattern)
        return unless matches

        group_name = matches[1]
        # option_name = matches[2].strip

        # TODO: Sanitize group name. Prevent Ruby error from Regex control chars
        pattern = /Option #{group_name}: ?(.+)/
        option_entities = tag.model.layers.sort_by(&:name).select { |t| t.name.match(pattern) }
        return if option_entities.size < 2

        option_names = option_entities.map { |t| t.name.match(pattern)[1] }

        # Assuming tag is the visible one
        # Not sure how to handle passing in a hidden tag, or one in a options group
        # where several are visible.
        # TODO: Make a decision. Maybe just document as unsupported?
        new(group_name, option_names, option_entities, option_entities.index(tag))
      end

      # FEATURE: Could also create from Group or tag folder.
      # For SU 2021 and later, prefer a tag group named "Options: {group_name}"

      # Create a new OptionsGroup. Prefer factory methods over this.
      #
      # @param name [String]
      # @param option_names [Array<String>]
      # @param option_entities [Array<Sketchup::Layer>]
      # @param index_selected [Integer]
      def initialize(name, option_names, option_entities, index_selected)
        @name = name
        @option_names = option_names
        @option_entities = option_entities
        @index = index_selected
      end

      # @return [String]
      attr_reader :name

      # @return [Array<String>]
      attr_reader :option_names

      # @return [Array<Sketchup::Layer>]
      attr_reader :option_entities # REVIEW: May change to allow Groups too.

      # @return [Integer]
      attr_reader :index

      # Display all the (typically overlapping) design options.
      # Can be useful to manage them together, e.g. move all fireplaces you are
      # considering for a design when you move the wall they are on.
      #
      # Should be called within start and commit operation.
      def show_all
        @option_entities.each { |t| t.visible = true }
      end

      # Cycle to the next design option.
      #
      # Should be called within start and commit operation.
      def show_next
        @index = (@index + 1) % @option_entities.size
        @option_entities.each_with_index { |t, i| t.visible = i == @index }
      end

      # Cycle to the previous design option.
      #
      # Should be called within start and commit operation.
      def show_prev
        @index = (@index - 1) % @option_entities.size
        @option_entities.each_with_index { |t, i| t.visible = i == @index }
      end

      # Show a specific design option.
      #
      # @param index [Integer]
      #
      # Should be called within start and commit operation.
      def show_by_index(index)
        @index = index
        @option_entities.each_with_index { |t, i| t.visible = i == @index }
      end

      # Check if the option by a certain index is visible.
      #
      # Note that more than one option can be visible.
      #
      # @param index [Integer]
      #
      # @return [Boolean]
      def index_visible?(index)
        @option_entities[index].visible?
      end

      # Shorthand for name of selected option.
      #
      # @return [String]
      def selected_name
        @option_names[@index]
      end

      # Shorthand for number of options in group.
      #
      # @return [Integer]
      def size
        @option_entities.size
      end
    end

    # Tool for managing visibility of design options.
    class OptionsTool
      # Create tool object.
      def initialize
        @options_group = nil
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def activate
        update_status_text
        Sketchup.active_model.start_operation("Show Design Option", true)
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def deactivate(view)
        view.model.commit_operation
        view.invalidate
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def draw(view)
        return unless @options_group

        view.tooltip =
          "#{@options_group.name}: #{@options_group.selected_name} "\
          "(#{@options_group.index + 1}/#{@options_group.size})"
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def getMenu(menu)
        @options_group.option_names.each_with_index do |name, index|
          item = menu.add_item(name) { @options_group.show_by_index(index) }
          menu.set_validation_proc(item) { @options_group.index_visible?(index) ? MF_CHECKED : MF_UNCHECKED }
        end
        menu.add_separator
        menu.add_item("Show All") { @options_group.show_all }
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onMouseMove(_flags, x, y, view)
        # TODO: Allow a few px of movement before picking again,
        # in case user accidentally nudges mouse while scrolling.
        # We want to hold on to the same options group, even if the newly displayed
        # options is physically smaller and no longer under the cursor.
        ph = view.pick_helper(x, y)
        entity = ph.best_picked

        @options_group = OptionsGroup.from_tag(entity.layer) if entity

        view.invalidate
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def onMouseWheel(flags, delta, _x, _y, view)
        # REVIEW: Show error tooltip if using shift scroll outside an options group?
        # Same for context menu? Offer to show docs?

        return unless @options_group
        return unless flags & CONSTRAIN_MODIFIER_MASK == CONSTRAIN_MODIFIER_MASK

        # Specifically hold on to @options_group instead of picking new.
        # Even if mouse is no longer hovering the same group, because the new
        # option is smaller in size, the user should be able to keep scroll to
        # cycle it.

        delta < 0 ? @options_group.show_next : @options_group.show_prev
        view.invalidate

        # Prevent zooming
        true
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def resume(_view)
        update_status_text
      end

      # @api
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def suspend(view)
        view.invalidate
      end

      private

      def update_status_text
        Sketchup.status_text =
          "Hover a design option, press Shift and scroll, or right click to cycle."
      end
    end

    command = UI::Command.new(EXTENSION.name) { Sketchup.active_model.select_tool(OptionsTool.new) }
    command.status_bar_text = EXTENSION.description

    menu = UI.menu("Plugins")
    menu.add_item(command)
  end
end
