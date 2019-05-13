require "./strcase.cr"

module TLpsrc2spec
  class TLPDB
    class Error < Exception
    end

    class UnsupportedTagFoundError < Exception
    end

    class PathInfo
      property path : String
      property details : String?
      property language : String?

      def initialize(@path, **info)
        @details = info[:details]?
        @language = info[:language]?
      end
    end

    class Files
      getter files : Set(PathInfo)
      property filesize : Int32
      property arch : String?

      include Enumerable(PathInfo)
      include Iterable(PathInfo)

      def initialize(@files, @filesize = 0, @arch = nil)
      end

      def initialize(@filesize = 0, @arch = nil, &block)
        @files = Set(PathInfo).new
        yield @files
      end

      def each(&block : PathInfo -> _)
        @files.each do |info|
          yield info
        end
      end

      def each
        @files.each
      end

      def empty?
        @files.empty?
      end
    end

    # List of tags which builds a list from each occurances.
    LIST_TAGS = %w[execute postaction]

    # List of tags which builds a list from each words.
    WORDS_TAGS = %w[catalogue-topics catalogue-also depend]

    # List of tags which stores a integer data
    INTEGER_TAGS = %w[revision relocated
      containersize doccontainersize srccontainersize]

    # List of tags which stores a time data
    TIME_TAGS = %w[catalogue-date]

    # List of tags which is a single line data
    SINGLE_TAGS = %w[name category shortdesc catalogue catalogue-ctan
      catalogue-license catalogue-version catalogue-contact-home
      catalogue-contact-repository catalogue-contact-announce
      catalogue-contact-bugs catalogue-contact-development
      catalogue-contact-support catalogue-alias
      containerchecksum doccontainerchecksum srccontainerchecksum]

    # List of tags which builds a multi-line string from each occurances.
    LONG_TAGS = %w[longdesc]

    # List of tags which defines list of files.
    FILES_TAGS = %w[runfiles srcfiles binfiles docfiles]

    ALL_TAGS_DATA_TYPE = {
      single:  {keys: SINGLE_TAGS, type: String},
      integer: {keys: INTEGER_TAGS, type: Int32},
      time:    {keys: TIME_TAGS, type: Time},
      list:    {keys: LIST_TAGS, type: Array(String)},
      long:    {keys: LONG_TAGS, type: String},
      files:   {keys: FILES_TAGS, type: Files},
      words:   {keys: WORDS_TAGS, type: Array(String)},
    }

    {% begin %}
      # Macro support constant for each tags. This should not be used
      # with compiled into executable file.
      ALL_TAGS_DATA = {
      {% for t, sym in ALL_TAGS_DATA_TYPE %}
        {% for name in sym[:keys].resolve %}
        {{name}} => {
          name: {{name}},
          type: :{{t.id}},
          const_symbol: :{{name.upcase.gsub(/-/, "_").id}},
          var_symbol: :{{name.gsub(/-/, "_").id}},
          data_type: {{sym[:type]}},
        },
        {% end %}
      {% end %}
    }
    {% end %}

    enum Tag
      {% for name, val, j in ALL_TAGS_DATA %}
        {{ val[:const_symbol].id }} = {{j + 100}}
      {% end %}

      def to_keystr
        {% begin %}
          case self
              {% for name, val in ALL_TAGS_DATA %}
              when {{val[:const_symbol].id}}
                {{name}}
              {% end %}
          else
            "(invalid tag: %d)" % {self.to_i32}
          end
        {% end %}
      end

      def self.from_string(str : String) : Tag
        {% begin %}
          case str
              {% for name, val in ALL_TAGS_DATA %}
              when {{name}}
                {{val[:const_symbol].id}}
              {% end %}
          else
            raise Exception.new("Invalid tag #{str}")
          end
        {% end %}
      end

      def self.from_symbol(sym : Symbol) : Tag
        {% begin %}
          case sym
              {% for name, val in ALL_TAGS_DATA %}
              when {{val[:var_symbol]}}
                {{val[:const_symbol].id}}
              {% end %}
          else
            raise Exception.new("Invalid tag #{sym}")
          end
        {% end %}
      end

      {% begin %}
        {% types = {} of SymbolLiteral => ArrayLiteral %}
        {% for name, val in ALL_TAGS_DATA %}
          {% if types[val[:type]].is_a?(NilLiteral) %}
            {% types[val[:type]] = [val] %}
          {% else %}
            {% types[val[:type]] << val %}
          {% end %}
        {% end %}
        {% for t, data in types %}
        def {{t.id}}?
          {% tags = data.map { |x| x[:const_symbol].id } %}
          case self
          when {{tags.splat}}
            true
          else
            false
          end
        end
        {% end %}
      {% end %}
    end

    class Package
      {% for name, data in ALL_TAGS_DATA %}
        getter {{data[:var_symbol].id}} : {{data[:data_type]}}?
      {% end %}

      {% begin %}
      def initialize(**args)
        {% for name, data in ALL_TAGS_DATA %}
          {% n = data[:var_symbol] %}
          @{{n.id}} = args[{{n}}]
        {% end %}
      end
      {% end %}

      def []?(tag : Tag)
        {% begin %}
          case tag
              {% for name, data in ALL_TAGS_DATA %}
              when Tag::{{data[:const_symbol].id}}
                {% mem = data[:var_symbol].id %}
                @{{mem}}
              {% end %}
          else
            nil
          end
        {% end %}
      end

      def [](tag : Tag)
        x = self[tag]?
        raise KeyError.new("#{tag.to_s} is invalid") if x.nil?
        x
      end
    end

    @db : Hash(String, Package) = {} of String => Package

    def register(pkg : Package)
      @db[pkg.name] = pkg
    end

    class ParseError < Error
    end

    class Parser
      @db : TLPDB
      @buf : StringCase::Buffer
      @lexeme : Int32 = -1
      {% begin %}
      @pkg_data_buffer : NamedTuple(
        {% for name, val in ALL_TAGS_DATA %}
          {% if val[:data_type].stringify == "Array(String)" %}
            {{val[:var_symbol].id}}: Array(String),
          {% elsif val[:data_type].stringify == "Files" %}
            {{val[:var_symbol].id}}: Hash(String?, Hash(String, String)?),
          {% else %}
            {{val[:var_symbol].id}}: IO::Memory,
          {% end %}
        {% end %}
      ) = {
        {% for name, val in ALL_TAGS_DATA %}
          {% if val[:data_type].stringify == "Array(String)" %}
            {{val[:var_symbol].id}}: [] of String,
          {% elsif val[:data_type].stringify == "Files" %}
            {{val[:var_symbol].id}}: {} of String? => Hash(String, String)?,
          {% else %}
            {{val[:var_symbol].id}}: IO::Memory.new,
          {% end %}
        {% end %}
      }
      {% end %}

      def initialize(io : IO, @db, bytesize : Int = 32)
        @buf = StringCase::Buffer.new(io, bytesize)
      end

      def initialize(buf : IO::Memory, @db)
        @buf = StringCase::Buffer.new(buf)
      end

      def initialize(buf : Bytes, @db)
        @buf = StringCase::Buffer.new(buf)
      end

      private def fill(n : Int) : Nil
        @buf.fill(n, @lexeme)
      end

      def eof? : Bool
        @buf.eof?
      end

      def parse
        fill(@buf.bytesize)
        while !eof?
          {% begin %}
            StringCase.strcase \
              case @buf
                  {% for name, val in ALL_TAGS_DATA %}
                  when {{name + " "}}
                    process_{{val[:type].id}}({{val[:var_symbol]}})
                  {% end %}
              when " ", "\n"
              else
                break if yych == '\u{0}'
                raise ParseError.new("Invalid Key at\n" +
                                     @buf.debug_cursor)
              end
          {% end %}
        end
        add_package
        @db
      end

      def get_rest_line
        @buf.token = @buf.cursor
        begin
          while (ch = @buf.next_char) == ' '
            @buf.token = @buf.cursor
          end
          while (ch = @buf.next_char) != '\n'
            # NOP
          end
        rescue IO::EOFError
        end
        slice = @buf.token_slice
        if slice.nil?
          raise Exception.new("Assertion failed: slice must be Slice")
        end
        slice
      ensure
        @buf.token = -1
      end

      private def get_single_data(data : IO::Memory)
        if data.size > 0
          String.new(data.buffer, data.size).chomp
        end
      end

      private def get_long_data(data : IO::Memory)
        if data.size > 0
          String.new(data.buffer, data.size)
        end
      end

      private def get_time_data(data : IO::Memory)
        if data.size > 0
          Time.parse!(String.new(data.buffer, data.size),
            "%Y-%m-%d %H:%M:%S %z")
        end
      end

      private def get_integer_data(data : IO::Memory)
        if data.size > 0
          String.new(data.buffer, data.size).to_i32
        end
      end

      private def get_list_data(data : Array(String))
        data.dup # Create a shallow copy (because `data` will be cleared)
      end

      private def get_words_data(data : Array(String))
        get_list_data(data)
      end

      private def get_files_data(data : Hash(String?, Hash(String, String)?))
        arch = nil
        size = 0
        global_info = data[nil]?
        if global_info
          if global_info.has_key?("size")
            size = global_info["size"].to_i
          end
          arch = global_info["arch"]?
        end

        Files.new(size, arch) do |lst|
          data.each do |path, info|
            next if path.nil?
            if info
              lst << PathInfo.new(path,
                details: info["details"]?,
                language: info["language"]?)
            else
              lst << PathInfo.new(path)
            end
          end
        end
      end

      private def add_package
        {% begin %}
          data = {
            {% for name, val in ALL_TAGS_DATA %}
              {{val[:var_symbol].id}}: get_{{val[:type].id}}_data(@pkg_data_buffer[{{val[:var_symbol]}}]),
            {% end %}
          }
          @db.add_package(Package.new(**data))
        {% end %}
      end

      private def new_package
        @pkg_data_buffer.each do |key, val|
          val.clear
        end
      end

      private def process_single(sym : Symbol)
        data = get_rest_line
        if sym == :name
          if !@pkg_data_buffer[:name].empty?
            add_package
          end
          new_package
        end
        io = @pkg_data_buffer[sym].as(IO::Memory)
        io.clear
        io.write data
      end

      private def process_time(sym : Symbol)
        process_single(sym)
      end

      private def process_integer(sym : Symbol)
        process_single(sym)
      end

      private def parse_keyval(valid_keys : Set(String)? = nil) : Hash(String, String)
        hsh = {} of String => String
        key = nil
        buf = IO::Memory.new
        instr = false
        @buf.token = @buf.cursor
        while !@buf.eof?
          ch = @buf.next_char
          case ch
          when ' ', '\n'
            if !instr
              str = @buf.token_slice
              if str && str.size > 0
                buf.write(str[0...-1])
              end
              if buf.size > 0 && key && key.size > 0
                hsh[key] = String.new(buf.buffer, buf.size)
              end
              if ch == '\n'
                @buf.token = -1
                break
              end
              @buf.token = @buf.cursor
              buf.clear
            end
          when '='
            if !instr
              str = @buf.token_slice
              if str && str.size > 0
                buf.write(str[0...-1])
              end
              if buf.size > 0
                key = String.new(buf.buffer, buf.size)
                if valid_keys && valid_keys.size > 0 && !valid_keys.includes?(key)
                  raise ParseError.new("Invalid key '#{key}'\n" +
                                       @buf.debug_cursor)
                end
              else
                raise ParseError.new("Empty key found\n" +
                                     @buf.debug_cursor)
              end
              @buf.token = @buf.cursor
              buf.clear
            end
          when '"'
            instr = !instr
            if instr
              @buf.token = @buf.cursor
            else
              slice = @buf.token_slice
              if slice
                buf.write(slice[0...-1])
              end
              @buf.token = -1
            end
          end
        end
        hsh
      end

      private def process_files(sym : Symbol)
        lst = @pkg_data_buffer[sym].as(Hash(String?, Hash(String, String)?))
        lst.clear
        entries = parse_keyval(Set{"size", "arch"})
        if entries.size > 0
          lst[nil] = entries
        end
        while !@buf.eof?
          ch = @buf.peek_char
          if ch != ' '
            break
          end
          @buf.next_char
          @buf.token = @buf.cursor
          while !@buf.eof? && (ch = @buf.next_char) == ' '
            @buf.token = @buf.cursor
          end
          break if @buf.eof?
          while !@buf.eof? && (ch = @buf.next_char)
            break if ch == ' ' || ch == '\n'
          end
          slice = @buf.token_slice
          @buf.token = -1
          filename = nil
          if slice
            filename = String.new(slice[0...-1])
          end
          break if @buf.eof?
          if ch != '\n'
            info = parse_keyval(Set{"details", "language"})
          else
            info = nil
          end
          lst[filename] = info
        end
      end

      private def process_list(sym : Symbol)
        data = get_rest_line
        lst = @pkg_data_buffer[sym].as(Array(String))
        lst << String.new(data).chomp
      end

      private def process_words(sym : Symbol)
        data = get_rest_line
        arr = String.new(data).chomp.split(/\s+/)
        lst = @pkg_data_buffer[sym].as(Array(String))
        lst.concat(arr)
      end

      private def process_long(sym : Symbol)
        data = get_rest_line
        io = @pkg_data_buffer[sym].as(IO::Memory)
        io.write(data)
      end
    end

    @db : Hash(String, Package) = {} of String => Package

    def [](name : String)
      @db[name]
    end

    def []?(name : String)
      @db[name]?
    end

    include Enumerable(Package)

    def each(&block)
      @db.each_value { |pkg| yield pkg }
    end

    enum ArrayQuery
      All = 1100
      Any = 1101
    end

    enum ValueQuery
      LT         = 1
      LE         = 2
      GT         = 3
      GE         = 4
      EQ         = 5
      NE         = 6
      StartsWith = 7
      EndsWith   = 8

      Less         = LT
      LessEqual    = LE
      Greater      = GT
      GreaterEqual = GE
      Equal        = EQ
      NotEqual     = NE
    end

    enum FileQuery
      Exact     = 100 # Matches to fullpath
      BaseName  = 101 # Matches basename of each paths.
      Directory = 102 # Matches any directory name.
      Path      = 103 # Matches to begginning path
      LastPath  = 104 # Matches to trailing path (does not include filename)
    end

    private def compare_data(data, query, mode : ValueQuery)
      case mode
      when ValueQuery::EQ
        data == query
      when ValueQuery::LE
        data <= query
      when ValueQuery::GE
        data >= query
      when ValueQuery::GT
        data > query
      when ValueQuery::LT
        data < query
      when ValueQuery::NE
        data != query
      else
        false
      end
    end

    private def query_single_data(data : String, query : String,
                                  mode : ValueQuery = ValueQuery::EQ)
      case mode
      when ValueQuery::StartsWith
        data.starts_with?(query)
      when ValueQuery::EndsWith
        data.ends_with?(query)
      else
        compare_data(data, query, mode)
      end
    end

    private def query_single_data(data : String, query : Regex)
      data =~ query
    end

    private def query_single_data(data : String,
                                  query : Tuple(ValueQuery, String))
      query_single_data(data, query[1], query[0])
    end

    private def query_long_data(*args)
      query_single_data(*args)
    end

    private def query_integer_data(data : Int, query : Int,
                                   mode : ValueQuery = ValueQuery::EQ)
      compare_data(data, query, mode)
    end

    private def query_integer_data(data : Int, query : Range(Int, Int))
      query.includes?(data)
    end

    private def query_integer_data(data : Int,
                                   query : Tuple(ValueQuery, Int32))
      query_integer_data(data, query[1], query[0])
    end

    private def qeury_list_data(data : Array(String),
                                query : Array(String),
                                amode : ArrayQuery = ArrayQuery::All,
                                vmode : ValueQeury = ValueQeury::EQ)
      case amode
      when ArrayQuery::All
        data.zip(query).all? do |a, b|
          query_single_data(a, b, vmode)
        end
      when ArrayQuery::Any
        data.zip(query).any? do |a, b|
          query_single_data(a, b, vmode)
        end
      else
        false
      end
    end

    private def query_words_data(*args)
      qeury_list_data(*args)
    end

    private def query_files_path_comp(path : String, query : String,
                                      vmode : ValueQuery, fmode : FileQuery)
      case fmode
      when FileQuery::Exact
        query_single_data(path, query, vmode)
      when FileQuery::BaseName
        query_single_data(File.basename(path), query, vmode)
      when FileQuery::Directory
        path.split("/").any? do |dir|
          query_single_data(dir, query, vmode)
        end
      when FileQuery::Path
        path.starts_with?(query)
      when FileQuery::LastPath
        File.dirname(path).ends_with?(query)
      else
        false
      end
    end

    private def query_files_data(data : Files, query : String | Regex,
                                 amode : ArrayQuery = ArrayQuery::Any,
                                 vmode : ValueQuery = ValueQuery::EQ,
                                 fmode : FileQuery = FileQuery::BaseName)
      if amode == ArrayQuery::Any
        data.any? do |x|
          query_files_path_comp(x.path, query, vmode, fmode)
        end
      else
        data.all? do |x|
          query_files_path_comp(x.path, query, vmode, fmode)
        end
      end
    end

    private def query_files_data(data : Files, query : Regex)
      data.any? { |x| x.path =~ query }
    end

    def [](**query) : Array(Package)
      arr = nil
      {% for name, val in ALL_TAGS_DATA %}
        {% tstr = val[:data_type].stringify %}
        {% array = (tstr =~ /Array(.*)|Files/) %}
        if (q = query[{{val[:var_symbol]}}]?)
          if arr.nil?
            arr = @db.values
          end
          arr.reject! do |x|
            data = x.{{val[:var_symbol].id}}
            next true if data.nil?
            next true if data.responds_to?(:empty?) && data.empty?
            !query_{{val[:type].id}}_data(data, q)
          end
        end
      {% end %}
      if arr.nil?
        [] of Package
      else
        arr
      end
    end

    def add_package(pkg : Package)
      name = pkg.name
      raise "Package name not defined" if name.nil?
      @db[name] = pkg
    end

    def self.parse(io : IO)
      parser = Parser.new(io, TLPDB.new)
      parser.parse
    end
  end
end
