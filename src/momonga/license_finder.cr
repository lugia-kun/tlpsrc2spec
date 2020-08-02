struct TLpsrc2spec::MomongaRule::LicenseFinder
  enum Condition
    None # Any of all candidated names
    Any  # Any of expected names
    All  # All of expected names
  end

  @[Flags]
  enum Category
    General # Genaral names
    Extra   # Extra names
  end

  # Generally used license file names (without extension)
  #
  # These names are case-insensitive.
  GENERAL_LICENSE_FILE_NAMES = [
    "COPYING", "LICENSE", "LICENCE",
    "IPA_Font_License_Agreement_v1.0",
    "IPA_Font_License_Agreement",
  ]

  GENERAL_LICENSE_FILE_EXTENSIONS = [
    ".txt", ".md", ".rst",
  ]

  struct Candidate
    property file
    property basename
    property category

    def initialize(@file : TLPDB::PathInfo, @category : Category, @basename = ::File.basename(path))
    end
  end

  private def check_general_name(file, io)
    {% begin %}
      basepos = io.pos
      StringCase.strcase(case_insensitive: true, complete: false) do
        case io
        when {{GENERAL_LICENSE_FILE_NAMES.splat}}
          check_general_name_ext(file, io, basepos)
        else
          nil
        end
      end
    {% end %}
  end

  private def warn_ext_not_match(file)
    Log.debug do
      String.build do |str|
        str << "Package '" << @tlpkg.name << "' has a "
        str << "file '" << file.path << "', but it "
        str << "has not been qualified as a license doc, "
        str << "because it does not match extension"
      end
    end
  end

  private def make_general_candidate(file, io, basepos)
    io.pos = basepos
    bname = io.gets_to_end
    Candidate.new(file, Category::General, bname)
  end

  private def check_general_name_ext(file, io, basepos)
    if io.eof?
      make_general_candidate(file, io, basepos)
    else
      {% begin %}
        StringCase.strcase(case_insensitive: true, complete: true) do
          case io
          when {{GENERAL_LICENSE_FILE_EXTENSIONS.splat}}
            make_general_candidate(file, io, basepos)
          else
            warn_ext_not_match(file)
            nil
          end
        end
      {% end %}
    end
  end

  @tlpkg : TLPDB::Package
  @licenses : Array(TLPDB::License)

  def initialize(@tlpkg, @licenses, *, @category = Category::All, @expected_names : Set(String)? = nil, @cond = ((e = @expected_names) && !e.empty?) ? Condition::All : Condition::None)
    @candidates = [] of Candidate
  end

  def find_in_list(list : TLPDB::Files, &block)
    list.each do |file|
      ret = yield file
      if ret
        @candidates << ret
      end
    end
  end

  def find(&block)
    {% for name, val in TLPDB::ALL_TAGS_DATA %}
      {% if val[:type] == :files %}
        list_of_files = @tlpkg.{{val[:var_symbol].id}}
        list_of_files.each do |files|
          find_in_list(files) do |file|
            yield file
          end
        end
      {% end %}
    {% end %}
  end

  def find_with_basename_strcase_io(&block)
    find do |file|
      io = StringCase::Single.new(file.path)
      # File.basename(x)
      posbase = 0
      while (ch = io.next_char)
        if ch == '/'
          posbase = io.pos
        end
      end
      io.pos = posbase
      yield file, io
    end
  end

  def find_with_default_names(&block)
    find_with_basename_strcase_io do |file, io|
      possave = io.pos
      if ret = yield file, io
        ret
      else
        io.pos = possave
        check_general_name(file, io)
      end
    end
  end

  # partition expected names by found and not found
  def partition_expected_names(expected_names = @expected_names)
    if !expected_names
      return {@candidates, Set(String).new}
    end
    notfound = expected_names.dup
    found = [] of Candidate
    @candidates.each do |cand|
      basename = cand.basename
      if notfound.includes? basename
        found << cand
        notfound.delete basename
      end
    end
    {found, notfound}
  end

  def result
    Log.debug do
      String.build do |str|
        str << "License file candidates of " << @tlpkg.name
        if (licenses = @licenses)
          str << " ("
          licenses.each_with_index do |l, i|
            if i != 0
              str << ", "
            end
            str << l
          end
          str << ")"
        end
      end
    end
    @candidates.each do |cand|
      Log.debug do
        String.build do |str|
          file = cand.file
          str << " * " << file.path
          if d = file.details
            str << " (" << d << ")"
          end
        end
      end
    end

    found, notfound = partition_expected_names
    if @cond == Condition::All
      if notfound.size > 0
        Log.warn do
          String.build do |str|
            str << @tlpkg.name << ": "
            if notfound.size > 1
              str << "All of following files are "
            else
              str << "Following file is "
            end
            str << "expected to exist0 as license document, but not found:"
          end
        end
        notfound.each do |name|
          Log.warn { " * #{name}" }
        end
        return nil
      end
    else
      priority = nil
      if @category.includes?(Category::Extra)
        priority = found.find do |cand|
          cand.category.includes?(Category::Extra)
        end
      end
      if priority
        found = priority
      else
        found = found.find do |cand|
          @category.includes?(cand.category)
        end
      end
      if found.nil?
        if notfound.size > 0
          Log.warn do
            String.build do |str|
              str << @tlpkg.name << ": "
              if notfound.size > 1
                str << "One of following files is "
              else
                str << "Following file is "
              end
              str << "expected to exist as license document, but not found:"
            end
          end
          notfound.each do |name|
            Log.warn { " * #{name}" }
          end
        else
          Log.warn do
            String.build do |str|
              str << @tlpkg.name
              if (lics = @licenses) && lics.size > 0
                str << " ("
                lics.reduce(false) do |b, l|
                  str << ", " if b
                  str << l
                  true
                end
                str << ")"
              end
              str << ": No license files found"
            end
          end
        end
        return nil
      end
    end
    found.not_nil! # not_nil! is just assertion. the method may return nil
  end

  def make_momonga_license_expression(found = result)
    if !found
      return nil
    elsif found.is_a?(Array)
      String.build do |str|
        str << "see"
        first = true
        found.each do |cand|
          str << " and" if !first
          str << " \"" << cand.basename << "\""
          first = false
        end
      end
    else
      "see \"#{found.basename}\""
    end
  end

  macro find_license_file(tlpkg, licenses, **args)
    {% has_extra_names = false %}
    {% expand_extra_names = false %}
    {% expected_names = nil %}
    {% cond = nil %}
    {% finder = "::TLpsrc2spec::MomongaRule::LicenseFinder".id %}
    {% extra_names = args[:extra_names] %}
    {% if extra_names.class_name == "ArrayLiteral" %}
      {% has_extra_names = true %}
      {% if extra_names.all? { |item| item.class_name == "StringLiteral" } %}
        {% expand_extra_names = true %}
        {% expected_names = "Set{#{extra_names.splat}}".id %}
        {% cond = "#{finder}::Condition::Any".id %}
      {% end %}
    {% end %}
    {% if !args[:expected_names] %}
      {% args[:expected_names] = expected_names %}
    {% end %}
    {% if !args[:cond] && cond %}
      {% args[:cond] = cond %}
    {% end %}
    {% tmp = {} of SymbolLiteral => ASTNode %}
    {% args.each { |k, v| tmp[k] = v if k != :extra_names } %}
    {% args = {expected_names: nil} %}
    {% tmp.each { |k, v| args[k] = v } %}
    begin
      {% if expand_extra_names %}
        %extra_names_checker = -> (file : TLPDB::PathInfo, io : StringCase::Single) do
          %possave = io.pos
          StringCase.strcase(case_insensitive: true, complete: true) do
            case io
            when {{extra_names.splat}}
              io.pos = %possave
              %bname = io.gets_to_end
              {{finder}}::Candidate.new(file, {{finder}}::Category::Extra, %bname)
            else
              nil
            end
          end
        end
      {% elsif extra_names %}
        %extra_names_set = {{extra_names}}.to_set
        %extra_names_checker = -> (file : TLPDB::PathInfo, io : StringCase::Single) do
          %possave = io.pos
          %bname = io.gets_to_end
          if %extra_names_set.includes?(%bname)
            {{finder}}::Candidate.new(file, {{finder}}::Category::Extra, %bname)
          else
            nil
          end
        end
      {% else %}
        %extra_names_checker = -> (file : TLPDB::PathInfo, io : StringCase::Single) do
          nil
        end
      {% end %}
      %finder = {{finder}}.new({{tlpkg}}, {{licenses}}, {{**args}})
      %finder.find_with_default_names(&%extra_names_checker)
      %finder.make_momonga_license_expression
    end
  end
end
