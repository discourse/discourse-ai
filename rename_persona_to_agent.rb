#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "date"

class PersonaToAgentRenamer
  def initialize
    @plugin_root = Dir.pwd
    @manifest = []
  end

  def run
    case ARGV[0]
    when "--content-only"
      validate_directory
      replace_content_in_files
      print_content_summary
    when "--migrations-only"
      validate_directory
      create_migration
      create_post_migration
      print_migration_summary
    else
      puts colorize("=" * 55, :blue)
      puts colorize("Renaming 'persona' to 'agent' throughout the codebase", :blue)
      puts colorize("=" * 55, :blue)
      puts colorize("Working in: #{@plugin_root}", :blue)

      validate_directory
      replace_content_in_files
      rename_files_and_directories
      create_migration
      create_post_migration
      print_summary
    end
  end

  private

  def colorize(text, color)
    colors = {
      red: "\033[0;31m",
      green: "\033[0;32m",
      yellow: "\033[0;33m",
      blue: "\033[0;34m",
      nc: "\033[0m",
    }
    "#{colors[color]}#{text}#{colors[:nc]}"
  end

  def validate_directory
    unless File.exist?(File.join(@plugin_root, "plugin.rb"))
      puts colorize("Error: Script must be run from the discourse-ai plugin root directory", :red)
      exit 1
    end
  end

  def git_tracked_files
    `git ls-files`.split("\n").map { |f| File.join(@plugin_root, f) }
  end

  def all_directories_with_persona
    # Find all directories that contain 'persona' in their name
    output = `find . -type d -name "*persona*" 2>/dev/null | grep -v "\\.git"`.split("\n")
    output.map { |dir| File.join(@plugin_root, dir.sub("./", "")) }
  end

  def replace_content_in_files
    puts colorize("Replacing content in files...", :blue)

    file_extensions = %w[rb js gjs yml erb scss hbs json]

    git_tracked_files.each do |file|
      # Skip files in db/ directory and tokenizers/
      next if file.include?("/db/")
      next if file.include?("/tokenizers/")
      next if !file_extensions.include?(File.extname(file)[1..-1])
      next if File.basename(file) == "rename_persona_to_agent.rb"
      next unless File.exist?(file)

      content = File.read(file)
      next unless content.match?(/persona/i)

      original_content = content.dup

      # Replace different case variations
      content.gsub!(/persona/, "agent")
      content.gsub!(/Persona/, "Agent")
      content.gsub!(/PERSONA/, "AGENT")

      # Handle special cases
      content.gsub!(/aiPersona/, "aiAgent")
      content.gsub!(/AIPersona/, "AIAgent")
      content.gsub!(/ai_persona/, "ai_agent")
      content.gsub!(/Ai_persona/, "Ai_agent")
      content.gsub!(/ai-persona/, "ai-agent")

      if content != original_content
        File.write(file, content)
        relative_path = file.sub("#{@plugin_root}/", "")
        puts colorize("Content updated: #{relative_path}", :green)
        @manifest << "Content updated: #{relative_path}"
      end
    end
  end

  def rename_files_and_directories
    puts colorize("Renaming files and directories using git mv...", :blue)

    # Get all directories with 'persona' in their path (excluding db/ and tokenizers/)
    # Sort by depth (deepest first) to avoid conflicts when renaming parent directories
    dirs_to_rename =
      all_directories_with_persona
        .select { |path| !path.include?("/db/") && !path.include?("/tokenizers/") }
        .sort_by { |path| -path.count("/") }

    # Get all files with 'persona' in their names (excluding db/ and tokenizers/)
    files_to_rename =
      git_tracked_files.select do |path|
        !path.include?("/db/") && !path.include?("/tokenizers/") &&
          File.basename(path).match?(/persona/i)
      end

    # First, rename individual files that have 'persona' in their filename
    puts colorize("  Renaming individual files with 'persona' in filename...", :blue)
    files_to_rename.each do |old_path|
      next unless File.exist?(old_path)
      next if File.basename(old_path) == "rename_persona_to_agent.rb"

      # Skip files that are inside directories we're going to rename
      # (they'll be handled when we rename the directory)
      next if dirs_to_rename.any? { |dir| old_path.start_with?(dir + "/") }

      new_path = old_path.gsub(/persona/, "agent").gsub(/Persona/, "Agent")

      if old_path != new_path
        # Ensure parent directory exists
        FileUtils.mkdir_p(File.dirname(new_path))

        # Use git mv to preserve history
        if system("git", "mv", old_path, new_path)
          old_relative = old_path.sub("#{@plugin_root}/", "")
          new_relative = new_path.sub("#{@plugin_root}/", "")
          puts colorize("    File renamed: #{old_relative} -> #{new_relative}", :green)
          @manifest << "File renamed: #{old_relative} -> #{new_relative}"
        else
          puts colorize("    Failed to rename: #{old_path}", :red)
        end
      end
    end

    # Then rename directories (deepest first to avoid path conflicts)
    puts colorize("  Renaming directories with 'persona' in path...", :blue)
    dirs_to_rename.each do |old_dir_path|
      next unless File.exist?(old_dir_path) && File.directory?(old_dir_path)

      new_dir_path = old_dir_path.gsub(/persona/, "agent").gsub(/Persona/, "Agent")

      if old_dir_path != new_dir_path && !File.exist?(new_dir_path)
        # Create parent directory if needed
        FileUtils.mkdir_p(File.dirname(new_dir_path))

        # Use git mv to preserve history for the entire directory tree
        if system("git", "mv", old_dir_path, new_dir_path)
          old_relative = old_dir_path.sub("#{@plugin_root}/", "")
          new_relative = new_dir_path.sub("#{@plugin_root}/", "")
          puts colorize("    Directory renamed: #{old_relative} -> #{new_relative}", :green)
          @manifest << "Directory renamed: #{old_relative} -> #{new_relative}"

          # Log all files that were moved as part of this directory rename
          if File.directory?(new_dir_path)
            Dir
              .glob("#{new_dir_path}/**/*", File::FNM_DOTMATCH)
              .each do |moved_file|
                next if File.directory?(moved_file)
                next if File.basename(moved_file).start_with?(".")

                # Calculate what the old path would have been
                relative_to_new_dir = moved_file.sub(new_dir_path + "/", "")
                old_file_path = File.join(old_dir_path, relative_to_new_dir)

                old_file_relative = old_file_path.sub("#{@plugin_root}/", "")
                new_file_relative = moved_file.sub("#{@plugin_root}/", "")
                puts colorize(
                       "      File moved: #{old_file_relative} -> #{new_file_relative}",
                       :green,
                     )
                @manifest << "File moved: #{old_file_relative} -> #{new_file_relative}"
              end
          end
        else
          puts colorize("    Failed to rename directory: #{old_dir_path}", :red)
        end
      end
    end
  end

  def create_migration
    puts colorize("Creating database migration to copy persona tables...", :blue)

    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    migration_file =
      File.join(@plugin_root, "db", "migrate", "#{timestamp}_copy_persona_tables_to_agent.rb")

    migration_content = <<~RUBY
      # frozen_string_literal: true

      class CopyPersonaTablesToAgent < ActiveRecord::Migration[7.0]
        def up
          # Copy the main table structure and data
          if table_exists?(:ai_personas) && !table_exists?(:ai_agents)
            execute <<~SQL
              CREATE TABLE ai_agents AS
              SELECT * FROM ai_personas
            SQL

            # Copy indexes from ai_personas to ai_agents
            execute <<~SQL
              CREATE UNIQUE INDEX index_ai_agents_on_id
              ON ai_agents USING btree (id)
            SQL

            # Copy any other indexes that exist on ai_personas
            indexes = execute(<<~SQL).to_a
              SELECT indexname, indexdef
              FROM pg_indexes
              WHERE tablename = 'ai_personas'
              AND indexname != 'ai_personas_pkey'
            SQL

            indexes.each do |index|
              new_index_def = index['indexdef'].gsub('ai_personas', 'ai_agents')
              new_index_name = index['indexname'].gsub('ai_personas', 'ai_agents')
              new_index_def = new_index_def.gsub(index['indexname'], new_index_name)
              execute(new_index_def)
            end
          end

          # Update polymorphic associations to point to new table
          execute <<~SQL
            UPDATE rag_document_fragments
            SET target_type = 'AiAgent'
            WHERE target_type = 'AiPersona'
          SQL

          execute <<~SQL
            UPDATE upload_references
            SET target_type = 'AiAgent'
            WHERE target_type = 'AiPersona'
          SQL
        end

        def down
          drop_table :ai_agents if table_exists?(:ai_agents)

          # Revert polymorphic associations
          execute <<~SQL
            UPDATE rag_document_fragments
            SET target_type = 'AiPersona'
            WHERE target_type = 'AiAgent'
          SQL

          execute <<~SQL
            UPDATE upload_references
            SET target_type = 'AiPersona'
            WHERE target_type = 'AiAgent'
          SQL
        end
      end
    RUBY

    FileUtils.mkdir_p(File.dirname(migration_file))
    File.write(migration_file, migration_content)

    relative_migration = migration_file.sub("#{@plugin_root}/", "")
    puts colorize("Created migration file: #{relative_migration}", :green)
    @manifest << "Created migration file: #{relative_migration}"
  end

  def create_post_migration
    puts colorize("Creating post-migration to drop old persona tables...", :blue)

    timestamp = (Time.now + 1).strftime("%Y%m%d%H%M%S") # Ensure this runs after the main migration
    post_migrate_dir = File.join(@plugin_root, "db", "post_migrate")
    migration_file = File.join(post_migrate_dir, "#{timestamp}_drop_persona_tables.rb")

    migration_content = <<~RUBY
      # frozen_string_literal: true

      class DropPersonaTables < ActiveRecord::Migration[7.0]
        def up
          # Drop the old table after copying to new one
          drop_table :ai_personas if table_exists?(:ai_personas)
        end

        def down
          raise IrreversibleMigration, "Cannot recreate dropped persona tables"
        end
      end
    RUBY

    FileUtils.mkdir_p(post_migrate_dir)
    File.write(migration_file, migration_content)

    relative_migration = migration_file.sub("#{@plugin_root}/", "")
    puts colorize("Created post-migration file: #{relative_migration}", :green)
    @manifest << "Created post-migration file: #{relative_migration}"
  end

  def print_content_summary
    puts colorize("Content replacement completed!", :green)
    puts colorize("Files updated: #{@manifest.count}", :yellow)
    @manifest.each { |change| puts "  #{change}" }
  end

  def print_migration_summary
    puts colorize("Database migrations created!", :green)
    puts colorize("Files created: #{@manifest.count}", :yellow)
    @manifest.each { |change| puts "  #{change}" }
  end

  def print_summary
    puts colorize("=" * 55, :blue)
    puts colorize("Completed renaming 'persona' to 'agent' in the codebase", :green)
    puts colorize("=" * 55, :blue)
    puts colorize("Changes made:", :yellow)
    @manifest.each { |change| puts "  #{change}" }
    puts colorize("Next steps:", :yellow)
    puts "1. Review changes with 'git diff'"
    puts "2. Run tests and fix any remaining issues"
    puts "3. Run the database migrations (migrate, then post_migrate)"
    puts colorize("=" * 55, :blue)
  end
end

# Run the renamer if this file is executed directly
PersonaToAgentRenamer.new.run if __FILE__ == $0
