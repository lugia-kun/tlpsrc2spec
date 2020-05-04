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

      def initialize(@files, *, @filesize = 0, @arch = nil)
      end

      def initialize(*, @filesize = 0, @arch = nil, &block)
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

    class Execute
      class AddMap < Execute
        enum MapType
          Map
          MixedMap
          KanjiMap
        end

        property maptype : MapType
        property mapfile : String

        def initialize(@maptype, @mapfile)
        end
      end

      class AddFormat < Execute
        property name : String
        property mode : String?
        property engine : String
        property patterns : String?
        property options : String
        property fmttriggers : Array(String)?

        def initialize(*, @name, @mode, @engine, @patterns,
                       @options, @fmttriggers)
        end

        def enabled?
          mode != "disabled"
        end
      end

      class AddHyphen < Execute
        property name : String
        property lefthyphenmin : String
        property righthyphenmin : String
        property synonyms : String?
        property file : String
        property file_patterns : String?
        property file_exceptions : String?
        property luaspecial : String?

        def initialize(*, @name, @lefthyphenmin, @righthyphenmin,
                       @synonyms, @file, @file_patterns, @file_exceptions,
                       @luaspecial)
        end
      end
    end

    class PostAction
      class ShortCut < PostAction
        property type : String
        property name : String
        property cmd : String

        def initialize(*, @type, @name, @cmd)
        end
      end

      class FileType < PostAction
        property name : String
        property cmd : String

        def initialize(*, @name, @cmd)
        end
      end

      class ProgId < PostAction
        property extension : String
        property filetype : String

        def initialize(*, @extension, @filetype)
        end
      end

      class FileAssoc < PostAction
        property extension : String
        property filetype : String

        def initialize(*, @extension, @filetype)
        end
      end

      class Script < PostAction
        property file : String

        def initialize(*, @file)
        end
      end
    end

    # List of tags which builds an execute command from each occurances.
    EXEC_TAGS = [
      {name: "execute", var_symbol: "executes"},
    ]

    # List of tags which is used for post action from postaction
    POSTACT_TAGS = [
      {name: "postaction", var_symbol: "postactions"},
    ]

    # List of tags which builds a list from each words.
    WORDS_TAGS = [
      "catalogue-topics",
      {name: "catalogue-also", var_symbol: "catalogue_alsoes"},
      {name: "depend", var_symbol: "depends"},
    ]

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
      single:  {keys: SINGLE_TAGS, type: String?},
      integer: {keys: INTEGER_TAGS, type: Int32?},
      time:    {keys: TIME_TAGS, type: Time?},
      exec:    {keys: EXEC_TAGS, type: Array(Execute)},
      postact: {keys: POSTACT_TAGS, type: Array(PostAction)},
      long:    {keys: LONG_TAGS, type: String?},
      files:   {keys: FILES_TAGS, type: Array(Files)},
      words:   {keys: WORDS_TAGS, type: Array(String)},
    }

    {% begin %}
      # Macro support constant for each tags. This should not be used
      # and compiled into executable file.
      ALL_TAGS_DATA = {
      {% for t, sym in ALL_TAGS_DATA_TYPE %}
        {% for data in sym[:keys].resolve %}
          {% if data.is_a?(NamedTupleLiteral) %}
            {% var_symbol = data[:var_symbol] %}
            {% const_symbol = data[:const_symbol] %}
            {% name = data[:name] %}
            {% if !name %}
              {% raise "TLPDB tag name is not given" %}
            {% end %}
          {% else %}
            {% var_symbol = nil %}
            {% const_symbol = nil %}
            {% name = data %}
          {% end %}
          {% if !var_symbol %}
            {% var_symbol = name.gsub(/-/, "_") %}
          {% end %}
          {% if !const_symbol %}
            {% const_symbol = var_symbol.upcase %}
          {% end %}
          {{name}} => {
            name: {{name}},
            type: :{{t.id}},
            const_symbol: :{{const_symbol.id}},
            var_symbol: :{{var_symbol.id}},
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
        getter {{data[:var_symbol].id}} : {{data[:data_type]}}
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
        {% types = {} of Symbol => String %}
        {% for name, val in ALL_TAGS_DATA %}
          {% if val[:data_type].stringify.starts_with? "Array(" %}
            {% types[val[:var_symbol]] = val[:data_type] %}
          {% elsif val[:data_type].stringify == "Files" %}
            {% types[val[:var_symbol]] = "Array(Files)" %}
          {% else %}
            {% types[val[:var_symbol]] = "IO::Memory" %}
          {% end %}
        {% end %}

        alias DataBufferType = NamedTuple(
                {% for name, val in types %}
                  {{name.id}}: {{val.id}},
                {% end %}
              )

        def self.clear_data_buffer(old : DataBufferType? = nil) : DataBufferType
          if old
            {
              {% for name, val in types %}
                {{name.id}}: old[:{{name.id}}].tap { |x| x.clear },
              {% end %}
            }
          else
            {
              {% for name, val in types %}
                {{name.id}}: {{val.id}}.new,
              {% end %}
            }
          end
        end
      {% end %}

      @pkg_data_buffer : DataBufferType = Parser.clear_data_buffer

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
            StringCase.strcase do
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

      private def get_exec_data(data : Array(Execute))
        data.dup
      end

      private def get_postact_data(data : Array(PostAction))
        data.dup
      end

      private def get_words_data(data : Array(String))
        get_list_data(data)
      end

      private def get_files_data(data : Array(Files))
        data.dup
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
        @pkg_data_buffer = Parser.clear_data_buffer(@pkg_data_buffer)
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

      macro parse_keyval(*keys, **valid_keys)
        {% data = {} of Symbol => (String | NamedTuple) %}
        {% for str in keys %}
          {% if str.is_a?(NamedTupleLiteral) %}
            {% data[str[:str].id] = str %}
          {% else %}
            {% data[str.id] = str %}
          {% end %}
        {% end %}
        {% for key, val in valid_keys %}
          {% data[key.id] = val %}
        {% end %}
        {% for key, val in data %}
          {% if val.is_a?(NamedTupleLiteral) %}
            {% str = val[:str] %}
            {% if !str %}
              {% raise "Matching string not given" %}
            {% end %}
          {% elsif val.is_a?(StringLiteral) %}
            {% data[key] = {str: val} %}
          {% else %}
            {% raise "#{val} must be StringLiteral or NamedTupleLiteral" %}
          {% end %}
        {% end %}

        %io = StringCase::Single.new(64)
        ret = parse_keyval_run do |ov, key, val|
          %io.clear
          %io.print(key)
          %io.pos = 0
          StringCase.strcase do
            case %io
                 {% for key, val in data %}
                 when {{val[:str]}}
                   {
                     {% for skey, sval in data %}
                       {% if skey == key %}
                           {{key.id}}: val,
                       {% else %}
                         {% k = skey.id %}
                         {{k}}: ((ov && ov[:{{k}}]?) ? ov[:{{k}}] : nil),
                         {% end %}
                     {% end %}
                   }
                 {% end %}
            else
              raise ParseError.new("Invalid key '#{key}'. Expecting one of:\n" +
                                   {% for key, val in data %}
                                     " * {{key.id}}\n" +
                                   {% end %}
                                   @buf.debug_cursor)
            end
          end
        end
        {% mand = [] of Symbol %}
        {% for key, val in data %}
          {% if val[:mandatory] %}
            {% mand << key %}
          {% end %}
        {% end %}
        {% if mand.size > 0 %}
          if !ret || [
              {% for x in mand %}
                :{{x.id}},
              {% end %}
            ].any? { |k| !ret[k] }
            {% mand_j = mand.join(", ") %}
            {% v = (mand.size > 1) ? "are" : "is" %}
            {% d = (mand.size > 1) ? "s" : "" %}
            not_founds = [
              {% for x in mand %}
                :{{x.id}},
              {% end %}
            ]
            if ret
              not_founds = not_founds.compact_map { |k| (!ret[k]) ? k : nil }
            end
            if not_founds.size > 1
              v = "are"
            else
              v = "is"
            end
            raise ParseError.new("Key{{d.id}} {{mand_j.id}} {{v.id}} mandatory, but #{not_founds.join(", ")} #{v} not found!\n" + @buf.debug_cursor)
          else
            {
              {% for key, val in data %}
                {% if val[:mandatory] %}
                  {{key.id}}: ret[:{{key.id}}].not_nil!,
                {% else %}
                  {{key.id}}: ret[:{{key.id}}],
                {% end %}
              {% end %}
            }
          end
        {% else %}
          {
            {% for key, val in data %}
              {{key.id}}: ret ? ret[:{{key.id}}] : nil,
            {% end %}
          }
        {% end %}
      end

      private def keyval_quote(buf, instr, chr)
        if instr == nil || instr == chr
          if instr.nil?
            instr = chr
          else
            instr = nil
          end
          if instr == chr
            @buf.token = @buf.cursor
          else
            slice = @buf.token_slice
            if slice
              buf.write(slice[0...-1])
            end
            @buf.token = -1
          end
        end
        instr
      end

      private def parse_keyval_run(&block)
        nt = nil
        key = nil
        buf = IO::Memory.new
        instr : Char? = nil
        @buf.token = -1
        while !@buf.eof?
          ch = @buf.next_char
          case ch
          when ' ', '\t', '\n'
            if instr.nil?
              if @buf.token >= 0 || buf.size > 0
                str = @buf.token_slice
                if str && str.size > 0
                  buf.write(str[0...-1])
                end
                # value may be empty.
                if key && key.size > 0
                  value = String.new(buf.buffer, buf.size)
                  nt = yield(nt, key, value)
                  buf.clear
                end
              end
              @buf.token = -1
              if ch == '\n'
                break
              end
            end
          when '='
            if !instr
              str = @buf.token_slice
              if str && str.size > 0
                buf.write(str[0...-1])
              end
              if buf.size > 0
                key = String.new(buf.buffer, buf.size)
              else
                raise ParseError.new("Empty key found\n" +
                                     @buf.debug_cursor)
              end
              @buf.token = @buf.cursor
              buf.clear
            end
          when '"'
            instr = keyval_quote(buf, instr, '"')
          when '\''
            instr = keyval_quote(buf, instr, '\'')
          else
            if @buf.token < 0
              @buf.token = @buf.cursor - 1
            end
          end
        end
        nt
      end

      private def process_files(sym : Symbol)
        lst = @pkg_data_buffer[sym].as(Array(Files))
        entries = parse_keyval("size", "arch")
        size = 0
        if entries && (strsz = entries[:size])
          if strsz
            size = strsz.to_i
          end
        end
        args = {
          filesize: size,
          arch:     (entries ? entries[:arch] : nil),
        }
        files = Files.new(**args) do |set|
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
            if !slice
              raise ParseError.new("Expected filename token\n" +
                                   @buf.debug_cursor)
            end
            filename = String.new(slice[0...-1])
            break if @buf.eof?
            info = nil
            if ch != '\n'
              info = parse_keyval("details", "language")
            end
            if info
              pi = PathInfo.new(filename, **info)
            else
              pi = PathInfo.new(filename)
            end
            set.add(pi)
          end
        end
        lst << files
      end

      private def process_addmap
        maptype = StringCase.strcase do
          case @buf
          when "Map "
            Execute::AddMap::MapType::Map
          when "MixedMap "
            Execute::AddMap::MapType::MixedMap
          when "KanjiMap "
            Execute::AddMap::MapType::KanjiMap
          else
            raise ParseError.new("Unsupported Map type\n" +
                                 @buf.debug_cursor)
          end
        end
        mapfile = get_rest_line
        Execute::AddMap.new(maptype, String.new(mapfile).chomp)
      end

      private def process_addformat
        info = parse_keyval({str: "name", mandatory: true},
          "mode", {str: "engine", mandatory: true},
          "patterns", {str: "options", mandatory: true},
          "fmttriggers")
        if info.nil?
          raise ParseError.new("No AddFormat data found\n" +
                               @buf.debug_cursor)
        end
        if t = info[:fmttriggers]?
          fmttriggers = t.split(",")
        end
        Execute::AddFormat.new(name: info[:name],
          mode: info[:mode]?,
          engine: info[:engine],
          patterns: info[:patterns]?,
          options: info[:options],
          fmttriggers: fmttriggers)
      end

      private def process_addhyphen
        info = parse_keyval({str: "name", mandatory: true},
          {str: "lefthyphenmin", mandatory: true},
          {str: "righthyphenmin", mandatory: true},
          "synonyms",
          {str: "file", mandatory: true},
          "file_patterns", "file_exceptions", "luaspecial")
        Execute::AddHyphen.new(name: info[:name],
          lefthyphenmin: info[:lefthyphenmin],
          righthyphenmin: info[:righthyphenmin],
          synonyms: info[:synonyms],
          file: info[:file],
          file_patterns: info[:file_patterns],
          file_exceptions: info[:file_exceptions],
          luaspecial: info[:luaspecial])
      end

      private def process_exec(sym : Symbol)
        com : Execute? = nil
        StringCase.strcase do
          case @buf
          when "add" # fontmap
            com = process_addmap
          when "AddFormat "
            com = process_addformat
          when "AddHyphen "
            com = process_addhyphen
          else
            raise ParseError.new("Unsupported Execute type\n" +
                                 @buf.debug_cursor)
          end
        end
        lst = @pkg_data_buffer[sym].as(Array(Execute))
        lst << com.not_nil!
      end

      private def process_shortcut
        info = parse_keyval({str: "type", mandatory: true},
          {str: "name", mandatory: true},
          {str: "cmd", mandatory: true})
        PostAction::ShortCut.new(**info)
      end

      private def process_filetype
        info = parse_keyval({str: "name", mandatory: true},
          {str: "cmd", mandatory: true})
        PostAction::FileType.new(**info)
      end

      private def process_progid
        info = parse_keyval({str: "extension", mandatory: true},
          {str: "filetype", mandatory: true})
        PostAction::ProgId.new(**info)
      end

      private def process_fileassoc
        info = parse_keyval({str: "extension", mandatory: true},
          {str: "filetype", mandatory: true})
        PostAction::FileAssoc.new(**info)
      end

      private def process_script
        info = parse_keyval({str: "file", mandatory: true})
        PostAction::Script.new(**info)
      end

      private def process_postact(sym : Symbol)
        com : PostAction? = nil
        StringCase.strcase do
          case @buf
          when "shortcut "
            com = process_shortcut
          when "filetype "
            com = process_filetype
          when "fileassoc "
            com = process_fileassoc
          when "progid "
            com = process_progid
          when "script "
            com = process_script
          else
            raise ParseError.new("Unsupported PostAction type\n" +
                                 @buf.debug_cursor)
          end
        end
        lst = @pkg_data_buffer[sym].as(Array(PostAction))
        lst << com.not_nil!
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

    private def qeury_list_data(data : Array(T),
                                query : Array(T),
                                amode : ArrayQuery = ArrayQuery::All,
                                vmode : ValueQeury = ValueQeury::EQ) forall T
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

    private def query_files_data(data : Array(Files), query : String | Regex,
                                 amode : ArrayQuery = ArrayQuery::Any,
                                 vmode : ValueQuery = ValueQuery::EQ,
                                 fmode : FileQuery = FileQuery::BaseName)
      if amode == ArrayQuery::Any
        data.any? do |set|
          set.any? do |x|
            query_files_path_comp(x.path, query, vmode, fmode)
          end
        end
      else
        data.all? do |set|
          set.all? do |x|
            query_files_path_comp(x.path, query, vmode, fmode)
          end
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
