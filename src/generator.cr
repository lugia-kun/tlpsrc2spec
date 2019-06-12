require "rpm"
require "./strcase"

module TLpsrc2spec
  class SpecGenerator
    property template : String | Path
    property packages : Hash(String, TLpsrc2spec::Package)
    property master : TLpsrc2spec::Package

    def initialize(@template, @packages, @master)
    end

    def test_spec(file_to_test : String)
      # librpm generates error message for the specfile.
      specfile = RPM::Spec.open(file_to_test)
      specfile.finalize
      true
    rescue e : Exception
      if !e.is_a?(Exception)
        raise e
      end
      false
    end

    def write_data(io : IO, data, *, join : String = ", ",
                   prefix : String = "", postfix : String = "",
                   newline_escape : Bool = false, spec_escape : Bool = false)
      active_io = IO::Memory.new
      active_io << prefix
      if data.is_a?(Enumerable)
        data.each_with_index do |item, i|
          if i > 0
            active_io << join
          end
          active_io << item
        end
      else
        active_io << data
      end
      active_io << postfix
      active_io.pos = 0
      first = true
      while (line = active_io.gets)
        if newline_escape
          if !first
            io << " \\\n"
          end
        end
        if !first
          io << "\n"
        end
        first = false
        if spec_escape
          escaped = line.gsub('\\', "\\\\")
          escaped = escaped.gsub('#', "\\#")
          escaped = escaped.gsub('%', "%%")
          io << escaped
        else
          io << line
        end
      end
      if !first
        io << "\n"
      end
    end

    def write_tag_line(io : IO, tagname : String, data, *, join : String = ", ")
      io << tagname << ":"
      ("BuildRequires  ".size - tagname.size).times do |i|
        io << " "
      end
      write_data(io, data, join: join, newline_escape: true)
    end

    def write_tag_depends(io : IO, tagname : String, data : Enumerable(String | RPM::Dependency))
      data.each do |item|
        case item
        when String
          write_tag_line(io, tagname, item)
        when RPM::Dependency
          text = String.build do |str|
            str << item.name
            f = item.flags
            if f.greater? || f.equal? || f.less?
              if f.greater?
                if f.equal?
                  str << " >= "
                else
                  str << " > "
                end
              elsif f.less?
                if f.equal?
                  str << " <= "
                else
                  str << " < "
                end
              elsif f.equal?
                str << " == "
              end
              str << item.version.to_vr
            end
          end
          write_tag_line(io, tagname, text)
        end
      end
    end

    def write_tag_paragraph(io : IO, tagname : String, master_name : String,
                            package_name : String, data, join : String = "\n",
                            **args)
      io << "\n"
      io << "%" << tagname
      if package_name != master_name
        if !package_name.starts_with?(master_name + "-")
          io << " -n " << package_name
        else
          io << " " << package_name.sub(master_name + "-", "")
        end
      end
      io << "\n"
      write_data(io, data, **args)
    end

    def write_tag(io : IO, package : Package, tagname : RPM::Tag)
      case tagname
      when RPM::Tag::Name
        write_tag_line(io, "Name", package.name)
      when RPM::Tag::Summary
        write_tag_line(io, "Summary", package.summary)
      when RPM::Tag::Version
        write_tag_line(io, "Version", package.version)
      when RPM::Tag::Release
        write_tag_line(io, "Release", package.release)
      when RPM::Tag::License
        write_tag_line(io, "License", package.license, join: " and ")
      when RPM::Tag::URL
        if package.url
          write_tag_line(io, "URL", package.url)
        end
      when RPM::Tag::RequireName
        write_tag_depends(io, "Requires", package.requires)
      when RPM::Tag::ObsoleteName
        write_tag_depends(io, "Obsoletes", package.obsoletes)
      when RPM::Tag::ProvideName
        write_tag_depends(io, "Provides", package.provides)
      when RPM::Tag::ConflictName
        write_tag_depends(io, "Conflicts", package.conflicts)
      when RPM::Tag::Group
        if package.group
          write_tag_line(io, "Group", package.group)
        end
      when RPM::Tag::BuildArchs
        if !package.archdep?
          write_tag_line(io, "BuildArch", "noarch")
        end
      when RPM::Tag::Description
        if package.description
          write_tag_paragraph(io, "description", @master.name,
            package.name, package.description)
        end
      when RPM::Tag::PostIn
        if package.post
          write_tag_paragraph(io, "post", @master.name,
            package.name, package.post)
        end
      when RPM::Tag::PostTrans
        if package.posttrans
          write_tag_paragraph(io, "posttrans", @master.name,
            package.name, package.posttrans)
        end
      when RPM::Tag::PostUn
        if package.postun
          write_tag_paragraph(io, "postun", @master.name,
            package.name, package.postun)
        end
      else
        raise "Unsupported tag name: #{tagname}"
      end
    end

    def write_master(io : IO)
      write_tag(io, @master, RPM::Tag::Summary)
      write_tag(io, @master, RPM::Tag::Name)
      write_tag(io, @master, RPM::Tag::Version)
      write_tag(io, @master, RPM::Tag::Release)
      write_tag(io, @master, RPM::Tag::License)
      write_tag(io, @master, RPM::Tag::Group)
      write_tag(io, @master, RPM::Tag::URL)
      write_tag(io, @master, RPM::Tag::BuildArchs)
      write_tag(io, @master, RPM::Tag::RequireName)
      write_tag(io, @master, RPM::Tag::ObsoleteName)
      write_tag(io, @master, RPM::Tag::ProvideName)
      write_tag(io, @master, RPM::Tag::ConflictName)
    end

    def write_master_description(io : IO)
      write_tag(io, @master, RPM::Tag::Description)
    end

    def write_subpackages(io : IO)
      @packages.each do |n, pkg|
        next if pkg.name == @master.name
        write_tag_paragraph(io, "package", @master.name, pkg.name, "")
        write_tag(io, pkg, RPM::Tag::Summary)
        write_tag(io, pkg, RPM::Tag::Group)
        if pkg.license.size > 0
          write_tag(io, pkg, RPM::Tag::License)
        end
        write_tag(io, pkg, RPM::Tag::URL)
        write_tag(io, pkg, RPM::Tag::BuildArchs)
        write_tag(io, pkg, RPM::Tag::RequireName)
        write_tag(io, pkg, RPM::Tag::ObsoleteName)
        write_tag(io, pkg, RPM::Tag::ProvideName)
        write_tag(io, pkg, RPM::Tag::ConflictName)
        write_tag(io, pkg, RPM::Tag::Description)
      end
    end

    def write_scripts(io : IO)
      [RPM::Tag::PostIn, RPM::Tag::PostUn, RPM::Tag::PostTrans].each do |t|
        @packages.each do |n, pkg|
          write_tag(io, pkg, t)
        end
      end
    end

    def write_files(io : IO)
      @packages.each do |n, pkg|
        files_data = String.build do |builder|
          last_attr = nil
          pkg.files.each do |entry|
            if last_attr != entry.attr
              entry.attr.to_s(builder, defattr: true)
              builder << "\n"
              last_attr = entry.attr
            end
            if entry.config
              builder << entry.config << " "
            end
            if entry.verify
              builder << "%verify(" << entry.verify << ") "
            end
            if entry.doc?
              builder << "%doc "
            end
            if entry.docdir?
              builder << "%docdir "
            end
            if entry.dir?
              builder << "%dir "
            end
            builder << entry.path << "\n"
          end
        end
        write_tag_paragraph(io, "files", @master.name, pkg.name, files_data)
      end
    end

    enum TemplateTag
      MASTER
      DESCRIPTION_MASTER
      SUB_PACKAGES
      SCRIPTS
      FILES
      END_MASTER
      END_DESCRIPTION_MASTER
    end

    def self.parse_template(template_input_io : IO,
                            &block : Bytes | TemplateTag -> Void)
      ssfp = StringCase::Buffer.new(template_input_io)
      susp = false
      while !ssfp.eof?
        ssfp.token = ssfp.cursor
        StringCase.strcase \
          case ssfp
        when "@@"
          StringCase.strcase \
            case ssfp
          when "MASTER@@"
            yield(TemplateTag::MASTER)
            susp = true
          when "SUB_PACKAGES@@"
            yield(TemplateTag::SUB_PACKAGES)
          when "DESCRIPTION_MASTER@@"
            yield(TemplateTag::DESCRIPTION_MASTER)
            susp = true
          when "SCRIPTS@@"
            yield(TemplateTag::SCRIPTS)
          when "FILES@@"
            yield(TemplateTag::FILES)
          when "END_MASTER@@"
            yield(TemplateTag::END_MASTER)
            susp = false
          when "END_DESCRIPTION_MASTER@@"
            yield(TemplateTag::END_DESCRIPTION_MASTER)
            susp = false
          else
            raise "Invalid Template Tag:\n" + ssfp.debug_cursor
          end
          if yych != '\n'
            while !ssfp.eof?
              case ssfp.next_char
              when '\n'
                break
              when ' ', '\t'
              else
                raise "Unexpected token:\n" + ssfp.debug_cursor
              end
            end
          end
        else
          if yych != '\n'
            while !ssfp.eof?
              if ssfp.next_char == '\n'
                break
              end
            end
          end
          if !susp
            yield(ssfp.token_slice.not_nil!)
          end
        end
      end
    end

    def generate_from(template_input_io : IO, output_io : IO)
      SpecGenerator.parse_template(template_input_io) do |tag_or_bytes|
        case tag_or_bytes
        when TemplateTag::MASTER
          write_master(output_io)
        when TemplateTag::SUB_PACKAGES
          write_subpackages(output_io)
        when TemplateTag::DESCRIPTION_MASTER
          write_master_description(output_io)
        when TemplateTag::SCRIPTS
          write_scripts(output_io)
        when TemplateTag::FILES
          write_files(output_io)
        when Bytes
          output_io.write tag_or_bytes
        end
      end
    end

    def generate_no_test(io : IO, *,
                         input_template : String | Path | IO = @template)
      if input_template.is_a?(IO)
        generate_from(input_template, io)
      else
        File.open(input_template, "r") do |fp|
          generate_from(fp, io)
        end
      end
    end

    def generate(io : IO, *,
                 input_template : String | Path | IO = @template,
                 do_test : Bool = true)
      nt_args = {input_template: input_template}
      if io.is_a?(File)
        generate_no_test(io, **nt_args)
        io.flush
        if do_test
          test_spec(io.path)
        else
          nil
        end
      else
        if do_test
          spec_data = String.build do |spec_data|
            generate_no_test(spec_data, **nt_args)
          end
          result = File.tempfile(@master.name, ".spec") do |tmpfile|
            tmpfile.print(spec_data)
            tmpfile.flush
            test_spec(tmpfile.path)
          end
          if result
            io.print(spec_data)
          end
          result
        else
          generate_no_test(io, **nt_args)
          nil
        end
      end
    end

    def generate(filename : String, **args)
      File.open(filename, "w") do |fp|
        generate(fp, **args)
      end
    end
  end
end
