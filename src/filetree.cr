module TLpsrc2spec
  class Package
  end

  class DirectoryTree
  end

  class FileNode
    getter name : String
    property package : Package?
    getter parent : DirectoryNode

    def initialize(@name, @parent, @package = nil)
    end

    def path(io : IO)
      ret = true
      if parent != self
        ret = parent.path(io)
      end
      if ret
        io << "/"
      end
      if @name != "/"
        io << @name
        true
      else
        false
      end
    end

    def path
      String.build do |x|
        path(x)
      end
    end

    def to_s(io : IO)
      io << "#<" << self.class << ": \""
      path(io)
      io << "\""
      if (pkg = @package)
        io << " (" << pkg.name << ")"
      end
      io << ">"
    end
  end

  class DirectoryNode < FileNode
    getter entries : DirectoryEntries = DirectoryEntries.new

    def initialize(@name, @parent = self, @package = nil)
    end

    def add_entry(entry : FileNode)
      entries[entry.name] = entry
    end
  end

  class DirectoryEntries < Hash(String, FileNode)
    alias Iterator = ValueIterator(String, FileNode)
  end

  class DirectoryTreeError < Exception
  end

  class NoSuchEntryError < DirectoryTreeError
  end

  class NotDirectoryError < DirectoryTreeError
  end

  class DirectoryTree
    getter root : DirectoryNode
    property cwd : DirectoryNode

    def initialize(@root = DirectoryNode.new("/"))
      @cwd = @root
    end

    private def lookup(path : String)
      io = IO::Memory.new(path)
      cur = @cwd
      root = true
      io.each_line('/', true) do |entry|
        case entry
        when ".."
          cur = cur.parent
        when ""
          if root
            cur = @root
          end
        when "."
          cur # NOP
        else
          begin
            if cur.responds_to?(:entries)
              ext = cur.entries[entry]
              if ext.is_a?(DirectoryNode)
                cur = ext
              else
                raise NotDirectoryError.new("Not directory: #{path}")
              end
            else
              raise NoSuchEntryError.new("No such directory: #{path}")
            end
          rescue KeyError
            raise NoSuchEntryError.new("No such directory: #{path}")
          end
        end
        root = false
      end
      cur
    end

    private def get_dir_and_name(path : String)
      dir = lookup(File.dirname(path))
      if path.ends_with?("/")
        base = nil
      else
        base = File.basename(path)
      end
      {dir, base}
    end

    def [](path : String)
      dir, name = get_dir_and_name(path)
      if name
        dir.entries[name]
      else
        dir
      end
    end

    def []?(path : String)
      dir, name = get_dir_and_name(path)
      if name
        dir.entries[name]?
      else
        dir
      end
    rescue e : NoSuchEntryError | NotDirectoryError
      nil
    end

    def mkdir(path : String)
      io = IO::Memory.new(path)
      cur = @cwd
      root = true
      io.each_line('/', true) do |entry|
        case entry
        when ""
          if root
            cur = @root
          end
        when "."
          cur # NOP
        else
          if cur.entries.has_key?(entry)
            cur = cur.entries[entry]
            if !cur.responds_to?(:entries)
              raise NotDirectoryError.new("Not Directory: " + cur.path)
            end
          else
            cur.add_entry(cur = DirectoryNode.new(entry, cur))
          end
        end
        root = false
      end
      cur
    end

    def insert(file : String)
      base = File.basename(file)
      dir = File.dirname(file)
      begin
        entry = lookup(dir)
      rescue NoSuchEntryError
        entry = mkdir(dir)
      end
      e = FileNode.new(base, entry)
      entry.add_entry(e)
      e
    end

    struct DrawTreeStack
      property tail : Pointer(DrawTreeStack)
      property? after_end : Bool = false

      def initialize(@tail = Pointer(DrawTreeStack).null)
      end
    end

    private def to_str_tree_recursive(loc : FileNode, io : IO,
                                      root : Pointer(DrawTreeStack))
      up = root
      tail = up.value.tail
      if !tail.null?
        while !tail.value.tail.null?
          if tail.value.after_end?
            io << "   "
          else
            io << " \u2502 "
          end
          up = tail
          tail = tail.value.tail
        end
        if tail.value.after_end?
          io << " \u2514\u2501"
        else
          io << " \u251c\u2501"
        end
      else
        tail = up
      end
      io << " " << loc.name
      if (pkg = loc.package)
        io << " (" << pkg.name << ")"
      end
      io << "\n"
      if loc.is_a?(DirectoryNode)
        stack = DrawTreeStack.new
        tail.value.tail = pointerof(stack)
        entries = loc.entries
        nentry = entries.size

        entries.each_with_index do |e, i|
          if i == nentry - 1
            stack.after_end = true
          end
          to_str_tree_recursive(e[1], io, root)
        end

        tail.value.tail = Pointer(DrawTreeStack).null
      end
    end

    def to_s(io : IO)
      stack = DrawTreeStack.new
      to_str_tree_recursive(@root, io, pointerof(stack))
    end

    class DepthIterator
      @from : DirectoryNode
      @stack : Array(DirectoryEntries::Iterator)

      include Iterator(FileNode)

      def initialize(@from)
        @stack = [@from.entries.each_value]
      end

      def next
        while true
          entry = @stack.first.next
          if entry.is_a?(Iterator::Stop)
            @stack.shift
            if @stack.empty?
              return stop
            end
            next
          end
          if entry.is_a?(DirectoryNode)
            @stack.unshift entry.entries.each_value
          end
          return entry
        end
        raise Exception.new("Unreachable reached")
      end
    end

    class BreadthIterator
      @from : DirectoryNode
      @stack : Array(DirectoryEntries::Iterator)

      include Iterator(FileNode)

      def initialize(@from)
        @stack = [@from.entries.each_value]
      end

      def next
        while true
          entry = @stack.first.next
          if entry.is_a?(Iterator::Stop)
            @stack.shift
            if @stack.empty?
              return stop
            end
            next
          end
          if entry.is_a?(DirectoryNode)
            @stack.push entry.entries.each_value
          end
          return entry
        end
        raise Exception.new("Unreachable reached")
      end
    end

    # Do depth-first iteration
    def each_entry_recursive(from : DirectoryNode = @root, &block)
      iter = DepthIterator.new(from)
      iter.each do |entry|
        yield entry
      end
    end

    # Returns depth-first traversing iterator
    def each_entry_recursive(from : DirectoryNode = @root)
      DepthIterator.new(from)
    end

    # Do breadth-first iteration
    def each_entry_breadth(from : DirectoryNode = @root, &block)
      iter = BreadthIterator.new(from)
      iter.each do |entry|
        yield entry
      end
    end

    # Returns depth-first traversing iterator
    def each_entry_breadth(from : DirectoryNode = @root)
      BreadthIterator.new(from)
    end

    def clear
      @root.entries.clear
    end
  end
end
