module McpTools
  class ListShelf < BaseTool
    FORMATS = %w[audio text].freeze
    MAX_LIMIT = 100

    tool_name "list_shelf"
    description "Lists the books on one shelf, newest first. status: done (finished), in_progress (reading or " \
      "listening now), want (the want-to-read list), owned (bought, not started). format audio keeps the books " \
      "with an audio edition in that status (listened), text the other formats (read). year keeps the books " \
      "finished that year. total counts the whole list, page further with offset."
    input_schema(properties: {
      status: { type: "string", enum: Reading::STATUSES },
      format: { type: "string", enum: FORMATS },
      year: { type: "integer", description: "Finish year, for status done" },
      offset: { type: "integer", minimum: 0, default: 0 },
      limit: { type: "integer", minimum: 1, maximum: MAX_LIMIT, default: 50 }
    }, required: [ "status" ])
    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

    def self.call(status:, server_context:, format: nil, year: nil, offset: 0, limit: 50)
      return fail_with(:inclusion, field: :status) unless Reading::STATUSES.include?(status)
      return fail_with(:inclusion, field: :format) unless format.nil? || FORMATS.include?(format)

      user = server_context[:user]
      shelf = Shelf.new(user)
      year = year&.to_i if status == "done"
      ids = shelf.ids { on_shelf?(it, status, year) }
      ids &= with_format(user, status, format) if format
      offset = [ offset.to_i, 0 ].max
      books = shelf.summaries(ids.drop(offset).first(limit.to_i.clamp(1, MAX_LIMIT)))

      header = "#{[ status, format, year ].compact.join(" ")}: #{ids.size} books"
      header += ", showing #{offset + 1}-#{offset + books.size}" if books.any? && books.size < ids.size
      respond([ header, *books.map { describe(it) } ].join("\n"),
        { status:, format:, year:, total: ids.size, offset:, books: }.compact)
    end

    def self.on_shelf?(key, status, year)
      case status
      when "done" then year ? key == year.to_s : key.match?(/\A\d+\z/) || key == "no_date"
      when "in_progress" then key == "now"
      else key == status
      end
    end

    def self.with_format(user, status, format)
      editions = user.editions.joins(:reading).where(readings: { status: })
      editions = format == "audio" ? editions.where(format: "audio") : editions.where.not(format: "audio")
      editions.distinct.pluck(:book_id)
    end
  end
end
