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
      property arch : String?

      def initialize(@path, **info)
        @details = info[:details]?
        @language = info[:language]?
        @arch = info[:arch]?
      end

      def initislize(@path, info : Hash(String, String) = {} of String => String)
        @detail = info["details"]?
        @langage = info["language"]?
        @arch = info["arch"]?
      end
    end

    class Files < Array(PathInfo)
      property size : Int32
      property arch : String?

      def initialize(files : Array(PathInfo), @size = 0, @arch = nil)
        super(*files)
      end
    end

    # List of tags which builds a list from each occurances.
    LIST_TAGS = %w[execute postaction]

    # List of tags which builds a list from each words.
    WORDS_TAGS = %w[catalogue-topics catalogue-also depend]

    # List of tags which stores a integer data
    INTEGER_TAGS = %w[revision]

    # List of tags which stores a time data
    TIME_TAGS = %w[catalogue-date]

    # List of tags which is a single line data
    SINGLE_TAGS = %w[name category shortdesc catalogue catalogue-ctan
      catalogue-license catalogue-version catalogue-contact-home
      catalogue-contact-repository catalogue-contact-announce
      catalogue-contact-bugs catalogue-contact-development
      catalogue-contact-support catalogue-alias]

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
      class Buffer < IO::Memory
        @io : IO?
        property lexeme : Int32 = -1
        property token : Int32 = -1
        property marker : Int32 = -1
        getter limit : Int32 = 0
        getter line : Int32 = 1
        getter column : Int32 = 0
        getter lastchar : Char = '\u{0}'
        @capacity : Int32
        @eof : Int32 = -1

        def initialize(@io : IO, @capacity : Int32 = 64)
          super(@capacity)
        end

        def fill(nbytes : Int, keep : Int = -1) : Int
          io = @io
          return keep if io.nil?
          return keep if @eof >= 0
          lexeme = keep
          lexeme = @token if lexeme < 0 || @token < keep
          lexeme = @marker if lexeme < 0 || @marker < keep
          lexeme = self.pos if lexeme < 0 || self.pos < keep
          if lexeme > 0
            nlp = (lexeme - 1).downto(0).each do |i|
              if self.buffer[i] == '\n'.ord
                break i
              end
            end
            if nlp && nlp != 0
              lexeme = nlp + 1
            end
            rem = String.new(self[0...lexeme])
            rem.each_char do |ch|
              if ch == '\n'
                @line += 1
                @column = 0
              else
                @column += 1
              end
            end

            cut = self[lexeme...@limit]
            cut.move_to(self.buffer, cut.size)
            self.pos -= lexeme
            @token -= lexeme if @token >= 0
            @marker -= lexeme if @marker >= 0
            @limit -= lexeme
            keep -= lexeme
          end
          nspace = @capacity
          sz = self.size
          nspace = sz if sz > nspace
          nspace -= @limit if @limit > 0
          if nspace < nbytes
            nspace = nbytes
          else
            nbytes = nspace
          end
          nread = 0
          if @eof < 0
            pos = self.pos
            begin
              self.pos = @limit
              nread = IO.copy(io, self, nspace)
            ensure
              self.pos = pos
            end
            if nread < nspace
              @eof = nread + @limit
            end
          end
          if nread < nbytes
            (nread...nbytes).each do |i|
              self.buffer[i] = 0
            end
          end
          if nread > 0
            @limit += nread
          end
          keep
        end

        def peek_char
          pos = self.pos
          begin
            read_char
          ensure
            self.pos = pos
          end
        end

        def cursor
          self.pos
        end

        def cursor=(n : Int32)
          self.pos = n
        end

        def [](range : Range(Int32, Int32))
          n = range.end - range.begin
          if !range.exclusive?
            n += 1
          end
          Slice.new(self.buffer + range.begin, n)
        end

        def token_slice
          if @token < 0
            nil
          else
            self[@token...self.pos]
          end
        end

        def eof?
          @eof >= 0 && self.pos >= @eof
        end

        def debug_cursor
          str = String.new(self.buffer, @limit)
          lines = str.split(/\n/)
          lsz = lines.size + @line
          lwid = 0
          while lsz > 0
            lwid += 1
            lsz /= 10
          end
          cursor = self.pos
          String.build do |str|
            lines.each_with_index do |s, i|
              str << " %*d: %s\n" % { lwid, i + @line, s }
              if cursor >= 0 && cursor < s.size
                str << " "
                lwid.times do
                  str << " "
                end
                str << "  "
                (cursor - 1).times do
                  str << "~"
                end
                str << "^\n"
                cursor = -1
              else
                cursor -= s.size + 1
              end
            end
          end
        end
      end

      @buf : Buffer
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

      def initialize(io : IO, bytesize : Int = 32)
        @buf = Buffer.new(io, bytesize)
      end

      def initialize(buf : IO::Memory)
        @buf = Buffer.new(buf)
      end

      def initialize(buf : Bytes)
        @buf = Buffer.new(buf)
      end

      private def fill(n : Int) : Nil
        @buf.fill(n, @lexeme)
      end

      def eof? : Bool
        @buf.eof?
      end

      private def peek_char : Char
        ch = @buf.peek_char
        if ch.nil? || ch == '\u{0}' || ch == Char::REPLACEMENT
          if !@buf.eof?
            @buf.fill(4, @lexeme)
            ch = @buf.peek_char
          end
        end
        raise IO::EOFError.new if ch.nil?
        ch
      end

      private def next_char : Char
        ch = @buf.read_char
        if ch.nil? || ch == '\u{0}' || ch == Char::REPLACEMENT
          if !@buf.eof?
            @buf.fill(4, @lexeme)
            ch = @buf.read_char
          end
        end
        raise IO::EOFError.new if ch.nil?
        ch
      end

      private def cursor
        @buf.cursor
      end

      private def marker
        @buf.marker
      end

      macro make_recursive_case(cursor, marker, save_mark, depth, *lists)
        {% m = {} of CharLiteral => ArrayLiteral %}
        {% has_end_here = nil %}
        {% not_matched = nil %}
        {% for x in lists %}
          {% str = x[0] %}
          {% if str.is_a?(StringLiteral) %}
            {% if str.size == depth %}
              {% has_end_here = x[1] %}
            {% else %}
              {% ch = str.chars[depth] %}
              {% if m[ch].is_a?(NilLiteral) %}
                {% m[ch] = [x] %}
              {% else %}
                {% m[ch] << x %}
              {% end %}
            {% end %}
          {% else %}
            {% not_matched = x[1] %}
          {% end %}
        {% end %}
        {% if not_matched %}
          {% for ch, data in m %}
            {% m[ch] << {nil, not_matched} %}
          {% end %}
        {% end %}
        {% if has_end_here && lists.size == (not_matched ? 2 : 1) %}
          {{ has_end_here.id }}
        {% else %}
          {% if has_end_here %}
            yych = peek_char
          {% else %}
            yych = next_char
          {% end %}
            case yych
                {% for c in m.keys %}
                when {{c}}
                  {% if save_mark %}
                {{marker}} = {{cursor}}
                  {% end %}
                  {% if has_end_here %}
                    next_char
                  {% end %}
                  make_recursive_case({{cursor}}, {{marker}}, false, {{depth + 1}}, {{m[c].splat}})
                {% end %}
                {% if has_end_here %}
                else
                  {{ has_end_here.id }}
                {% else %}
                else
                  {% if depth > 0 %}
              {{ cursor }} = {{ marker }}
                  {% end %}
                  {% if not_matched %}
              {{ not_matched.id }}
                  {% end %}
                {% end %}
            end
        {% end %}
      end

      macro strcase(case_stmt)
        {% if !case_stmt.is_a?(Case) %}
          {% raise "case_stmt must be Case statement" %}
        {% end %}
        {% whens = case_stmt.whens %}
        {% not_matched = case_stmt.else %}
        {% lists = [] of Tuple(NilLiteral | StringLiteral | ASTNode) %}
        {% for w in whens %}
          {% for c in w.conds %}
            {% if !c.is_a?(StringLiteral) %}
              {% raise "conditionals must be a literal string" %}
            {% end %}
            {% lists << {c, "#{w.body}"} %}
          {% end %}
        {% end %}
        {% if !not_matched.is_a?(Nop) %}
          {% lists << {nil, "#{not_matched}"} %}
        {% end %}
        make_recursive_case(cursor, marker, true, 0, {{lists.splat}})
      end

      def parse
        fill(@buf.bytesize)
        while !eof?
          {% begin %}
            strcase \
              case yych
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
      end

      def get_rest_line
        @buf.token = @buf.cursor
        while (ch = next_char) == ' '
          @buf.token = @buf.cursor
        end
        while (ch = next_char) != '\n'
          # NOP
        end
        slice = @buf.token_slice
        if slice.nil?
          raise Exception.new("Assertion failed: slice must be Slice")
        end
        slice
      ensure
        @buf.token = -1
      end

      private def add_package
        hsh = {} of Symbol => (Array(String) | String | Int32 | Time | Files | Nil)
        @pkg_data_buffer.each do |key, val|
          tag = Tag.from_symbol(key)
          if val.is_a?(IO::Memory)
            if val.size == 0
              data = nil
            else
              data = String.new(val.buffer, val.size)
              if tag.single?
                data = data.chomp
              elsif tag.integer?
                data = data.to_i32
              elsif tag.time?
                data = Time.parse!(data.chomp, "%Y-%m-%d %H:%M:%S %z")
              end
            end
          elsif val.is_a?(Hash(String?, Hash(String, String)?))
            if val.size == 0
              data = nil
            else
              data = nil
            end
          else
            data = val
          end
          hsh[key] = data
        end
        pp hsh
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
          ch = next_char
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
          ch = peek_char
          if ch != ' '
            break
          end
          next_char
          @buf.token = @buf.cursor
          while !@buf.eof? && (ch = next_char) == ' '
            @buf.token = @buf.cursor
          end
          break if @buf.eof?
          while !@buf.eof? && (ch = next_char)
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



  end
end

psr = TLpsrc2spec::TLPDB::Parser.new(STDIN)
psr.parse
