module StringCase
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

    def initialize(@io : IO? = nil, @capacity : Int32 = 64)
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
          self.buffer[@limit + i] = 0
        end
      end
      if nread > 0
        @limit += nread
      end
      keep
    end

    private def peek_char_impl
      pos = self.pos
      begin
        ch = read_char
      ensure
        self.pos = pos
      end
    end

    def peek_char : Char
      pos = self.pos
      ch = peek_char_impl
      if ch.nil? || ch == '\u{0}' || ch == Char::REPLACEMENT
        if !eof?
          fill(4, @lexeme)
          pos = self.pos
          ch = peek_char_impl
        end
      end
      raise IO::EOFError.new if ch.nil?
      ch
    end

    def next_char : Char
      ch = read_char
      if ch.nil? || ch == '\u{0}' || ch == Char::REPLACEMENT
        if !eof?
          fill(4, @lexeme)
          ch = read_char
        end
      end
      raise IO::EOFError.new if ch.nil?
      ch
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
        last = self.pos
        if @eof >= 0 && last > @eof
          last = @eof
        end
        self[@token...last]
      end
    end

    def eof?
      @eof >= 0 && self.pos >= @eof
    end

    def debug_cursor(io : IO)
      str = String.new(self.buffer, @limit)
      lines = str.split(/\n/)
      lsz = lines.size + @line
      lwid = 0
      while lsz > 0
        lwid += 1
        lsz /= 10
      end
      cursor = self.pos

      lines.each_with_index do |s, i|
        io << " %*d: %s\n" % {lwid, i + @line, s}
        if cursor >= 0 && cursor <= s.size
          io << " "
          lwid.times do
            io << " "
          end
          io << "  "
          (cursor - 1).times do
            io << "~"
          end
          io << "^\n"
          cursor = -1
        else
          cursor -= s.size + 1
        end
      end
      if cursor >= 0
        io << " "
        lwid.times do
          io << " "
        end
        io << "  "
        (cursor - 1).times do
          io << "~"
        end
        io << "^\n"
        cursor = -1
      end
    end

    def debug_cursor
      String.build do |builder|
        debug_cursor(builder)
      end
    end
  end

  class Single < IO::Memory
    @peek : Bool = false
    @lchar : Char? = '\u0000'
    property marker : Int32 = -1

    def peek_char
      if @peek
        @lchar
      else
        @peek = true
        @lchar = read_char
      end
    end

    def next_char
      @peek = false
      @lchar = read_char
    end

    def eof?
      self.pos >= self.size
    end

    def cursor
      self.pos
    end

    def cursor=(val : Int32)
      self.pos = val
    end
  end

  macro make_recursive_case(case_io, save_mark, depth, test_eof,
                            case_sensitive, accept, not_matched, *lists)
    {% m = {} of CharLiteral => ArrayLiteral %}
    {% has_end_here = nil %}
    {% for x in lists %}
      {% str = x[0] %}
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
    {% end %}
    {% if has_end_here && lists.size == 1 %}
      {% if test_eof %}
        if {{case_io}}.peek_char.nil?
          {{case_io}}.marker = -1
          {{ has_end_here.id }}
        else
          {% if depth > 0 %}
            {{case_io}}.cursor = {{case_io}}.marker
            {{case_io}}.marker = -1
          {% end %}
          {% if accept %}
            {{ accept.id }}
          {% elsif not_matched %}
            {{ not_matched.id }}
          {% end %}
        end
      {% else %}
        {{case_io}}.marker = -1
        {{ has_end_here.id }}
      {% end %}
    {% else %}
      {% if has_end_here && !test_eof %}
        yych = {{case_io}}.peek_char
      {% else %}
        yych = {{case_io}}.next_char
      {% end %}
        case yych
            {% for c in m.keys %}
              {% if case_sensitive %}
              when {{c}}
              {% else %}
                {% s = c.id.stringify %}
                {% cup = s.upcase.chars[0] %}
                {% cdn = s.upcase.downcase.chars[0] %}
                {% if cup == cdn %}
                when {{cup}}
                {% else %}
                when {{cup}}, {{cdn}}
                {% end %}
              {% end %}
              {% if save_mark %}
                {{case_io}}.marker = {{case_io}}.cursor
              {% end %}
              {% if has_end_here && !test_eof %}
                {% if !save_mark %}
                {{case_io}}.marker = {{case_io}}.cursor
                {% end %}
                ::StringCase.make_recursive_case({{case_io}}, false, {{depth + 1}}, {{test_eof}}, {{case_sensitive}}, {{has_end_here}}, {{not_matched}}, {{m[c].splat}})
              {% else %}
                ::StringCase.make_recursive_case({{case_io}}, false, {{depth + 1}}, {{test_eof}}, {{case_sensitive}}, nil, {{not_matched}}, {{m[c].splat}})
              {% end %}
            {% end %}
        else
          {% if has_end_here %}
            {% if test_eof %}
              if {{case_io}}.peek_char.nil?
                {{case_io}}.marker = -1
                {{has_end_here.id}}
              else
                {% if depth > 0 %}
                  {{case_io}}.cursor = {{case_io}}.marker
                  {{case_io}}.marker = -1
                {% end %}
                {% if accept %}
                  {{ accept.id }}
                {% elsif not_matched %}
                  {{ not_matched.id }}
                {% end %}
              end
            {% else %}
              {{case_io}}.marker = -1
              {{has_end_here.id}}
            {% end %}
          {% else %}
            {% if depth > 0 %}
              {{case_io}}.cursor = {{case_io}}.marker
              {{case_io}}.marker = -1
            {% end %}
            {% if accept %}
              {{ accept.id }}
            {% elsif not_matched %}
              {{ not_matched.id }}
            {% end %}
          {% end %}
        end
    {% end %}
  end

  macro strcase_base(test_eof, case_sensitive, case_stmt)
    {% if !case_stmt.is_a?(Case) %}
      {% raise "case_stmt must be Case statement" %}
    {% end %}
    {% obj = case_stmt.cond %}
    {% whens = case_stmt.whens %}
    {% not_matched = case_stmt.else %}
    {% lists = [] of Tuple(NilLiteral | StringLiteral | ASTNode) %}
    {% for w in whens %}
      {% for c in w.conds %}
        {% if !c.is_a?(StringLiteral) %}
          {% raise "conditionals must be a literal string" %}
        {% end %}
        {% if !case_sensitive %}
          {% c = c.upcase %}
        {% end %}
        {% lists << {c, "#{w.body}"} %}
      {% end %}
    {% end %}
    {% if not_matched.is_a?(Nop) %}
      {% not_matched = nil %}
    {% else %}
      {% not_matched = "#{not_matched}" %}
    {% end %}
    ::StringCase.make_recursive_case({{obj}}, true, 0, {{test_eof}},
                                     {{case_sensitive}}, nil,
                                     {{not_matched}}, {{lists.splat}})
  end

  #
  macro strcase(case_stmt)
    ::StringCase.strcase_base(false, true, {{case_stmt}})
  end

  macro strcase_complete(case_stmt)
    ::StringCase.strcase_base(true, true, {{case_stmt}})
  end

  macro strcase_complete_case_insensitive(case_stmt)
    ::StringCase.strcase_base(true, false, {{case_stmt}})
  end

  macro strcase_case_insensitive(case_stmt)
    ::StringCase.strcase_base(false, false, {{case_stmt}})
  end
end
