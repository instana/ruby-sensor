# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'time'

module RuboCop
  module Cop
    module Instana
      # Ensures the license header is present in each ruby file
      class LicenseHeader < Base
        extend AutoCorrector

        MSG = 'The license header should be present in each file.'.freeze
        HEADER = '(c) Copyright IBM Corp.'
        HEADER_TEMPLATE = <<~HERE
         # (c) Copyright IBM Corp. %d
         # (c) Copyright Instana Inc. %d
        HERE

        def on_new_investigation
          first_statement = processed_source.tokens.detect { |t| t.type != :tCOMMENT }
          file_name = first_statement.pos.source_buffer.name
          header_comment = processed_source.comments.detect do |comment|
            first_statement_line = first_statement.pos.line
            comment_line = comment.loc.line

            (comment_line < first_statement_line) && comment.text.include?(HEADER)
          end

          return if header_comment

          add_offense(first_statement.pos) do |corrector|
            current_year = Time.now.year
            created_time = `git log --diff-filter=A --follow --format=%aD -1 -- #{file_name}`
            created_year = created_time.empty? ? current_year : Time.parse(created_time).year

            header_text = format(HEADER_TEMPLATE, current_year, created_year)
            corrector.insert_before(first_statement.pos, "\n#{header_text}\n")
          end
        end
      end
    end
  end
end
