#!/usr/bin/env ruby

require 'open3'
require 'optparse'

class RecursiveGitMktree

  def initialize(base_commit, null_delimited)
    @stack = Array.new
    @base_commit = base_commit
    @z = null_delimited
    @delim = "\n"
    @git_ls_tree_cmd = ['git', 'ls-tree']
    @git_mktree_cmd = ['git', 'mktree']
    if null_delimited
      @git_ls_tree_cmd.push '-z'
      @git_mktree_cmd.push '-z'
      @delim = "\0"
    end
    @component = nil
    @idx = nil
    @input = nil
    @output = nil
    @wait_thr = nil
    @instance_var_hash = nil
    @blob_dir = nil
    @blob_buffer = nil
    @blob_buffer_size = 100
  end

  def flush_blob_buffer
    IO.popen([@git_ls_tree_cmd, "#{@base_commit}:#{@blob_dir}", '--', @blob_buffer].flatten) do |f|
      IO.copy_stream f, @input
    end
    @blob_buffer.clear
  end

  def handle_file component
    if @blob_buffer.push(component).size >= @blob_buffer_size
      flush_blob_buffer
    end
  end

  def dir_push component, idx
    @input.write '040000 tree '
    @stack.push @instance_var_hash
    init_git_mktree component, idx
  end

  def init_git_mktree component, idx
    hash = {:@component => component,
            :@idx => idx,
            :@blob_dir => component == nil ? '' : @blob_dir + component + '/',
            :@blob_buffer => Array.new}
    hash[:@input], hash[:@output], hash[:@wait_thr] = Open3.popen2(*@git_mktree_cmd)
    hash.each &method(:instance_variable_set)
    @instance_var_hash = hash
  end

  def finalize_node
    if !@blob_buffer.empty?
      flush_blob_buffer
    end
    @input.close
    tree_hash = @output.gets.chomp
    @output.close
    return tree_hash
  end

  def dir_pop hash
    tree_hash = finalize_node
    closing_component = @component
    hash.each &method(:instance_variable_set)
    @instance_var_hash = hash
    @input.write "#{tree_hash}\t#{closing_component}#{@delim}"
  end

  def mktree files
    init_git_mktree nil, 0
    files.each(@delim) do |file|
      file.chomp!(@delim)
      path_components = file.split('/')
      path_components.each.with_index 1 do |component, idx|
        if @stack.size >= idx
          compare = @stack.size == idx ? @component : @stack[idx][:@component]
          if component == compare
            next
          else
            @stack.pop(@stack.size - idx + 1).reverse.each &method(:dir_pop)
          end
        end
        if idx < path_components.size
          dir_push component, idx
        else
          handle_file component
        end
      end
    end
    @stack.pop(@stack.size).reverse.each &method(:dir_pop)
    puts finalize_node
  end

end

options = { base_commit:'HEAD',
            null_delimited:false}

OptionParser.new do |opts|
  opts.banner = "Usage: git-mktree-recursive.rb [options]"

  opts.on('-c', '--base-commit=val', 
      'base commit for resolving blobs; defaults to HEAD') do |val|
    options[:base_commit] = val
  end

  opts.on('-z', '--null-delimited', 
      'expect null-delimited input, all internal handling is null-delimited') do |val|
    options[:null_delimited] = val
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

RecursiveGitMktree.new(options[:base_commit], options[:null_delimited]).mktree $stdin
