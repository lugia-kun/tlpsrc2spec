require "./strcase"

{% if compare_versions(Crystal::VERSION, "0.28.999999") < 0 %}
  # Monkey-Patching Set.
  struct Set(T)
    def delete_if(&block)
      @hash.delete_if do |*args|
        yield *args
      end
    end
  end
{% end %}

module TLpsrc2spec
  class MomongaRule < Rule
    @tree : DirectoryTree

    def initialize(*args)
      @tree = DirectoryTree.new
      super(*args)
    end

    def arch_name?(name) : String | Tuple(String, String) | Nil
      case name
      when "infra", "config", "image", "installer", "installation"
        nil
      when "win32"
        "win32"
      when /^([^-]+)-([^-]+)$/
        arch = $1
        os = $2
        {$1, $2}
      else
        raise Exception.new("Invalid arch name: #{name}")
      end
    end

    def add_texlive_prefix(name : String)
      String.build { |x| x << "texlive-" << name }
    end

    def add_texlive_prefix_if_required(name : String)
      # if name.starts_with?("texlive-")
      #   log.warn { "Not adding prefix \"texlive-\" for \"#{name}\"" }
      #   return name
      # end
      if name.starts_with?("texlive.")
        return add_texlive_prefix(name.sub(".", "-"))
      end
      # if name.starts_with?("kpathsea") ||
      #    name.starts_with?("ptexenc")
      #  return name
      # end
      add_texlive_prefix(name)
    end

    # Find license resource file
    def see_license(tlpkg : TLPDB::Package, license_name : String? = nil,
                    expected_filename : String = "LICENSE")
      candidates = [] of TLPDB::PathInfo
      {% for name, val in TLPDB::ALL_TAGS_DATA %}
        {% if val[:type] == :files %}
          files = tlpkg.{{val[:var_symbol].id}}
          if files
            files.each do |x|
              bn = File.basename(x.path)
              if bn =~ /^(COPYING|LICENSE|GUST-FONT-(NOSOURCE-)?LICENSE|
                          COPYRIGHT|IPA_Font_License_Agreement)/ix
                candidates << x
              end
            end
          end
        {% end %}
      {% end %}

      if candidates.empty?
        log.warn do
          String.build do |io|
            io << "License file not found in TL package "
            io << tlpkg.name
            if license_name
              io << " (" << license_name << ")"
            end
          end
        end
        "see \"#{expected_filename}\""
      else
        log.debug { "License file candidates of #{tlpkg.name} (#{license_name})" }
        candidates.each do |cand|
          log.debug { " * #{cand.path} (#{cand.details})"}
        end
        path = candidates.first.path
        "see \"#{File.basename(path)}\""
      end
    end

    def parse_license(tlpkg : TLPDB::Package, tlpdb_license_name : String)
      tlpdb_name = tlpkg.name
      if tlpdb_name
        tlpdb_name_stream = StringCase::Single.new(tlpdb_name)
        StringCase.strcase_complete \
          case tlpdb_name_stream
          when "almfixed"
            # See https://ctan.org/pkg/almfixed
            # File not included
            return "see \"GUST-FONT-LICENSE.txt\""
          when "arphic-ttf", "arphic"
            # See https://ctan.org/pkg/arphic
            # See https://ctan.org/pkg/arphic-ttf
            # arphic does not include the file.
            # arphic-ttf wrongly detected.
            return "see \"ARPHICPL.txt\""
          when "awesomebox"
            # See https://ctan.org/pkg/awesomebox
            # WTFPL (but Momonga does not accept this)
            return "\"WTFPL\""
          when "beamertheme-metropolis"
            # See https://ctan.org/tex-archive/macros/latex/contrib/beamer-contrib/themes/metropolis
            # CC-BY-SA 4.0 International
            return "CC-BY-SA"
          when "berenisadf"
            # See https://ctan.org/tex-archive/fonts/berenisadf
            return ["GPLv2", "see \"COPYING\", LPPL"]
          #when "blacklettert1"
          #  # See https://ctan.org/tex-archive/fonts/gothic/blacklettert1
          #  # It seems slightly different to LPPL 1.2.
          #  return "LPPL"
          when "borceux", "breakcites"
            # See https://ctan.org/pkg/borceux
            # See https://ctan.org/pkg/breakcites
            return "see \"README\""
          when "calligra", "calligra-type1"
            # See https://ctan.org/tex-archive/fonts/calligra
            # See https://ctan.org/tex-archive/fonts/calligra-type1
            return "see \"README\""
          when "charter"
            # See https://ctan.org/pkg/charter
            return "see \"readme.charter\""
          when "cherokee"
            # See https://ctan.org/tex-archive/fonts/cherokee
            return "see \"cherokee.mf\""
          when "chicago"
            # See https://ctan.org/tex-archive/biblio/bibtex/contrib/chicago
            return "see \"chicago.sty\""
          when "cite"
            # See https://ctan.org/tex-archive/macros/latex/contrib/cite
            return "see \"README\""
          when "cjk-ko"
            # See https://ctan.org/pkg/cjk-ko
            return ["GPL", "LPPL", "Public Domain"]
          when "clock"
            # Detected COPYING is GPLv2
            # (Maybe Incomlete to apply GPL?)
            return "GPLv2"
          when "codepage"
            # See https://ctan.org/pkg/codepage
            return "see \"README\""
          when "colorprofile"
            # See https://ctan.org/pkg/colorprofiles
            return "zlib"
          when "context"
            # See https://ctan.org/pkg/context
            # They say see "readme", but which file is that?
            log.warn { "License documentation of context has not found yet" }
            return "see \"README\""
          when "context-mathsets"
            # See https://ctan.org/pkg/context-mathsets
            # See t-mathsets.tex
            return "Modified BSD"
          when "context-rst"
            # See https://ctan.org/pkg/context-rst
            # from mtx-t-rst.lua.
            return "Modified BSD"
          when "courseoutline"
            # See https://ctan.org/tex-archive/macros/latex/contrib/courseoutline
            # NOTE: courceouline.cls uses CR and LF (not CRLF) for
            #       line-terminator.
            return "see \"courseoutline.cls\""
          when "courcepaper"
            # See https://ctan.org/tex-archive/macros/latex/contrib/coursepaper
            # NOTE: courcepaper.cls uses CR for line-terminator.
            return "see \"courcepaper.cls\""
          when "crossword"
            # See https://ctan.org/pkg/crossword
            return "see \"cwpuzzle.dtx\""
          when "csplain"
            # See https://ctan.org/pkg/csplain
            return "see \"csplain.ini\""
          when "cstex"
            # See https://ctan.org/pkg/cstex
            # They say this document does not mean GPLv2.
            return "see \"lic-gpl.eng\""
          when "cv4tw"
            # See https://ctan.org/pkg/cv4tw
            return "see \"LICENSE\""
          when "dancers"
            # See https://ctan.org/pkg/dancers
            return "see \"dancers.mf\""
          when "de-macro"
            # See https://ctan.org/pkg/de-macro
            return "see \"READNE\""
          when "detex"
            # See https://ctan.org/pkg/detex
            return "see \"README\""
          when "din1505"
            # See https://ctan.org/pkg/din1505
            return "see \"abbrvdin.bst\""
          when "doc-pictex"
            # See https://ctan.org/pkg/doc-pictex
            return "see \"Doc-PiCTeX.txt\""
          when "docbytex"
            # See https://ctan.org/pkg/docbytex
            return "see \"README\""
          when "dotseqn"
            # See https://ctan.org/pkg/dotseqn
            return "see \"dotseqn.dtx\""
          when "doublestroke"
            # See https://ctan.org/pkg/doublestroke
            return "see \"README\""
          when "dvidvi"
            # See https://ctan.org/pkg/dvidvi
            return "see \"README\""
          when "dvips"
            # See https://ctan.org/pkg/dvips
            # The file does not included 'texmf' files
            return ["Public Domain", "GPL", "see \"README\""]
          when "ec"
            # See https://ctan.org/pkg/ec
            return "see \"copyrite.txt\""
          when "electrum"
            # See https://ctan.org/pkg/electrumadf
            return ["LPPL", "GPL"]
          when "elvish"
            # See https://ctan.org/pkg/elvish
            return "see \"README\""
          when "epstopdf"
            # See https://ctan.org/pkg/epstopdf
            return "see \"epstopdf.pl\""
          when "eqname"
            # See https://ctan.org/pkg/eqname
            return "see \"eqname.sty\""
          when "fancynum"
            # See https://ctan.org/pkg/fancynum
            return "LPPL"
          when "fbithesis"
            # See https://ctan.org/pkg/fbithesis
            return "see \"README\""
          when "figflow"
            # See https://ctan.org/pkg/figflow
            return "see \"figflow.tex\""
          when "finbib"
            # See https://ctan.org/pkg/finplain
            return "see \"finplain.bst\""
          when "fltpoint"
            # See https://ctan.org/pkg/fltpoint
            return "LPPL"
          when "fonetika"
            # See https://ctan.org/pkg/fonetika
            # GPL and GUST FONT LICENSE.
            return "see \"README\""
          when "font-change"
            # See https://ctan.org/pkg/font-change
            # CC-BY-SA 3.0 Unported
            return "CC-BY-SA"
          when "font-change-xetex"
            # See https://ctan.org/pkg/font-change-xetex
            # CC-BY-SA 4.0 International
            return "CC-BY-SA"
          when "framed"
            # See https://ctan.org/pkg/framed
            return "see \"framed.sty\""
          when "fundus-calligra"
            # See https://ctan.org/pkg/fundus-calligra
            return "LPPL"
          when "fwlw"
            # See https://ctan.org/pkg/fwlw
            return "see \"fwlw.sty\""
          when "gene-logic"
            # See https://ctan.org/pkg/gene-logic
            return "see \"gn-logic14.sty\""
          when "gentium-tug"
            # See https://ctan.org/tex-archive/fonts/gentium-tug
            # (They say Expat License)
            return ["OFL", "MIT"]
          when "gentle"
            # See https://ctan.org/pkg/gentle
            return "see \"gentle.tex\""
          when "germbib"
            # See https://ctan.org/pkg/germbib
            return "see \"gerabbrv.bst\""
          when "gfsartemisia"
            # See https://ctan.org/pkg/gfsartemisia
            return ["OFL", "LPPL"]
          when "gfsbaskerville"
            # See https://ctan.org/pkg/gfsbaskerville
            return ["OFL", "LPPL"]
          when "gfsdidot"
            # See https://ctan.org/pkg/gfsdidot
            return ["OFL", "LPPL"]
          when "gfsneohellenic"
            # See https://ctan.org/pkg/gfsneohellenic
            return ["OFL", "LPPL"]
          when "gfsporson"
            # See https://ctan.org/pkg/gfsporson
            return ["OFL", "LPPL"]
          when "harvmac"
            # See https://ctan.org/pkg/harvmac
            # CC-BY 3.0 Unported
            return "Creative Commons"
          when "hc"
            # See https://ctan.org/pkg/hc
            return "GPLv2"
          when "hyph-utf8"
            # See https://ctan.org/pkg/hyph-utf8
            # Mainly CC0 but it is not all.
            return "CC0"
          when "hyphen-basque"
            # See https://ctan.org/pkg/bahyph
            return "see \"bahyph.tex\""
          when "hyphen-greek"
            # See https://ctan.org/pkg/elhyphen
            return "see \"copyrite.txt\""
          when "hyphen-turkish"
            # See https://ctan.org/pkg/tkhyph
            return "see \"tkhyph.tex\""
          when "hyphenex"
            # See https://ctan.org/pkg/hyphenex
            return "see \"README\""
          when "ifsym"
            # See https://ctan.org/pkg/ifsym
            return "LPPL"
          when "index"
            # See https://ctan.org/pkg/index
            return ["LPPL", "see \"xplain.bst\""]
          when "jadetex"
            # See https://ctan.org/pkg/jadetex
            return "see \"jadetex.dtx\""
          when "jamtimes"
            # See https://ctan.org/pkg/jamtimes
            return "see \"jamtimes.dtx\""
          when "karnaugh-map" # not "karnaughmap"
            # See https://ctan.org/pkg/karnaugh-map
            return "see \"README.md\""
          when "kastrup"
            # See https://ctan.org/pkg/binhex
            return "see \"binhex.dtx\""
          when "kixfont"
            # See https://ctan.org/pkg/kixfont
            return "see \"kix.mf\""
          when "l2tabu"
            # See https://ctan.org/pkg/l2tabu
            return "see \"l2tabu.tex\""
          when "l2tabu-italian"
            # See https://ctan.org/pkg/l2tabu-italian
            return "see \"l2tabuit.tex\""
          when "latexcourse-rug"
            # See https://ctan.org/pkg/latexcourse-rug
            return "see \"README\""
          when "lhcyr"
            # See https://ctan.org/pkg/lhcyr
            return "see \"README\""
          when "localloc"
            # See https://ctan.org/pkg/localloc
            return "see \"localloc.dtx\""
          when "lshort-germen"
            # See https://ctan.org/pkg/lshort-german
            # The full-text license is not included.
            return "see \"README.l2kurz\""
          when "lshort-spanish"
            # See https://ctan.org/pkg/lshort-spanish
            log.warn { "License of lshort-spanish unknown" }
            return "see \"LEAME.utf8\""

          when "2up"
            # According to 2up.tex
            return "LPPL"
          when "abstyles"
            log.warn { "License of abstyles unknown" }
            return "LPPL"
          when "xetex"
            # According to `xetex --help`
            return "see \"COPYING\""
          when "zed-csp"
            return "see \"zed-csp.sty\""
          when "uwmslide"
            # See https://ctan.org/pkg/uwmslide
            return "Artistic"
          when "was"
            # See https://ctan.org/tex-archive/macros/latex/contrib/was
            return "LPPL"
          when "eijkhout"
            # See https://ctan.org/pkg/eijkhout
            return ["GPL", "LPPL"]
          when "preprint"
            # See https://ctan.org/pkg/preprint
            return "LPPL"
          when "ltxmisc"
            # See https://ctan.org/tex-archive/macros/latex/contrib/misc
            return [
              # bibcheck.sty
              "GPLv2+",
              # beletter.cls
              "Public Domain",
              # vrtbexin.sty is Non-Commercial only.
              "see \"vrbexin.sty\"",
              # iagproc.cls, nextpage.sty, texilikechaps.sty, topcapt.sty
              "LPPL"
            ]
          when "fragments"
            # See https://ctan.org/pkg/fragments
            return ["Public Domain", "LPPL"]
          when "frankenstein"
            # See https://ctan.org/pkg/frankenstein
            return ["LPPL", "GPL"]
          when "gothic"
            # See https://ctan.org/pkg/gothic
            return [
              "Public Domain",
              "LPPL",
              "see \"COPYING\"" # blacklettert1
            ]
          when "npp-for-context"
            # See https://github.com/luigiScarso/context-npp
            return "GPLv3"
          when "beebe"
            log.warn { "License of beebe (catalogue biblio) is not known" }
            return "LPPL"
          when "arabi-add"
            # See https://ctan.org/tex-archive/language/arabic/arabi-add
            return "LPPL"
          end
      end

      license = StringCase::Single.new(tlpdb_license_name)
      ret = [] of String
      while !license.eof?
        StringCase.strcase \
          case license
          when "gpl"
            save = license.pos
            ch = license.next_char
            case ch
            when '1'
              # GPLv1?
              ret << "GPL"
            when '2'
              save = license.pos
              ch = license.next_char
              if ch == '+'
                ret << "GPLv2+"
              else
                license.pos = save
                ret << "GPLv2"
              end
            when '3'
              save = license.pos
              ch = license.next_char
              if ch == '+'
                ret << "GPLv3+"
              else
                license.pos = save
                ret << "GPLv3"
              end
            else
              license.pos = save
              ret << "GPL"
            end
          when "lgpl"
            save = license.pos
            StringCase.strcase \
              case license
              when "2.1"
                ret << "LGPLv2"
              when "3"
                ret << "LGPLv3"
              else
                license.pos = save
                ret << "LGPL"
              end
          when "fdl"
            ret << "GFDL"
          when "lppl"
            save = license.pos
            ch = license.next_char
            case ch
            when '1'
              save = license.pos
              StringCase.strcase \
                case license
                when ".2"
                  ret << "LPPL"
                when ".3"
                  save = license.pos
                  ch = license.next_char
                  case ch
                  when 'a', 'b', 'c'
                    ret << "LPPL"
                  else
                    license.pos = save
                    ret << "LPPL"
                  end
                else
                  license.pos = save
                  ret << "LPPL"
                end
            else
              license.pos = save
              ret << "LPPL"
            end
          when "cc0"
            ret << "CC0"
          when "pd"
            ret << "Public Domain"
          when "ofl"
            ret << "OFL"
          when "mit"
            ret << "MIT"
          when "apache2"
            ret << "ASL 2.0"
          when "bsd"
            save = license.pos
            ch = license.next_char
            case ch
            when '2', '4'
              ret << "BSD" # Momonga does not approve yet.
            when '3'
              ret << "Modified BSD"
            else
              license.pos = save
              ret << "BSD" # Momonga does not approve yet.
            end
          when "cc-by-"
            StringCase.strcase \
              case license
              when "1", "2", "3", "4"
                ret << "Creative Commons"
              when "sa-1", "sa-2", "sa-3", "sa-4"
                ret << "CC-BY-SA"
              when "nd-1", "nd-2", "nd-3", "nd-4"
                # CC-BY-ND
                log.error { "#{tlpkg.name}: CC-BY-ND is not \"free culture license\"" }
                stat = true
                ret << see_license(tlpkg)
              when "nc-"
                StringCase.strcase \
                  case license
                  when "1", "2", "3", "4"
                    # CC-BY-NC
                    log.error { "#{tlpkg.name}: CC-BY-NC is not \"free culture license\"" }
                    stat = 1
                    ret << see_license(tlpkg)
                  when "sa-1", "sa-2", "sa-3", "sa-4"
                    # CC-BY-NC-SA
                    log.error { "#{tlpkg.name}: CC-BY-NC-SA is not \"free culture license\"" }
                    stat = 1
                    ret << see_license(tlpkg)
                  when  "nd-1", "nd-2", "nd-3", "nd-4"
                    # CC-BY-NC-ND
                    log.error { "#{tlpkg.name}: CC-BY-NC-ND is not \"free culture license\"" }
                    stat = 1
                    ret << see_license(tlpkg)
                  else
                    log.error { "Unknown lincese: #{tlpdb_license_name}" }
                    return nil
                  end
              else
                log.error { "Unknown lincese: #{tlpdb_license_name}" }
                return nil
              end
          when "artistic"
            save = license.pos
            ch = license.next_char
            if ch == '2'
              ret << "Artistic"
            else
              license.pos = save
              ret << "Artistic"
            end
          when "knuth" # See https://ctan.org/license/knuth
            ret << see_license(tlpkg, "Knuth License")
          when "gfl"
            ret << see_license(tlpkg, "GUST Font License")
          when "gfsl" # GUST Font (Source) License
            ret << see_license(tlpkg, "GUST Font Source License")
          when "opl"
            ret << see_license(tlpkg, "Open Publication License")
          when "other-free"
            ret << see_license(tlpkg, "other-free license")
          when "collection"
            log.error { "Please inspect collection license for #{tlpkg.name}" }
            return nil
          when "noinfo"
            log.error { "Please inspect noinfo license for #{tlpkg.name}" }
            return nil
          else
            log.error { "Unknown lincese for #{tlpkg.name}: #{tlpdb_license_name}" }
            return nil
          end
      end
      ret
    end

    def package_name_from_tlpdb_name(name : String)
      case name
      when /^00texlive/
        nil
      when "collection-wintools"
        nil
      when "collection-texworks", "texworks"
        # TL does not provide TeXworks for UNIX-like OSs.
        nil
      when /^psutils/, /^t1utils/
        nil
      when "axessibility", "guide-latex-fr" # License issue.
        nil
      when /^(.*)\.([^\.]+)$/
        if $2.ends_with?("-linux")
          bin_name = String.build { |x| x << $1 << "-bin" }
          add_texlive_prefix_if_required(bin_name)
        elsif !arch_name?($2)
          log.warn do
            String.build do |x|
              x << "Package name with dot(s): " << name
            end
          end
          add_texlive_prefix_if_required(name)
        else
          nil
        end
      else
        add_texlive_prefix_if_required(name)
      end
    end

    def make_solib_package(name : String, *,
                           libname : String = "lib" + name,
                           include_subdir : String | Array(String)? = name,
                           has_include : Bool = true,
                           tlpkg : TLPDB::Package | String? = name,
                           has_static : Bool = false)
      if tlpkg.is_a?(String)
        tlpkg = app.tlpdb[tlpkg]
      end
      kpsedevname = package_name_from_tlpdb_name(name + "-devel")
      kpselibname = package_name_from_tlpdb_name(name + "-libs")
      if kpsedevname
        kpsedev = Package.new(kpsedevname,
                              summary: "Development files for #{name}",
                              group: "Development/Libraries",
                              archdep: true,
                              description: <<-EOD)
          This package contains development files for #{name}.
        EOD
        if has_include
          if include_subdir
            if include_subdir.responds_to?(:each)
              dirs = include_subdir
            else
              dirs = { include_subdir }
            end
          else
            dirs = { "*" }
          end
          dirs.each do |x|
            kpsedev.files << FileEntry.new(File.join(INCLUDEDIR, x))
          end
        end
        if has_static
          kpsedev.files << FileEntry.new(File.join(LIBDIR, "#{libname}*.a"))
        end
        kpsedev.files << FileEntry.new(File.join(LIBDIR, "#{libname}*.so"))
      end
      if kpselibname
        kpselib = Package.new(kpselibname,
                              summary: "Library files of #{name}",
                              group: "System Envrionment/Libraries",
                              archdep: true,
                              description: <<-EOD)
          This package contains library files of #{name}.
        EOD
        kpselib.files << FileEntry.new(File.join(LIBDIR, "#{libname}*.so.*"))
      end
      if kpsedev && kpselib
        kpsedev.requires << kpselib.name
      end
      xtlpkg = nil
      if tlpkg
        # Create TLPDB package with no files.
        {% begin %}
          xtlpkg = TLPDB::Package.new(
            {% for name, val in TLPDB::ALL_TAGS_DATA %}
              {% n = val[:var_symbol] %}
              {% t = val[:type] %}
              {% if t != :files %}
                {{n.id}}: tlpkg.{{n.id}},
              {% else %}
                {{n.id}}: nil,
              {% end %}
            {% end %}
          )
        {% end %}
      end
      if kpsedev
        if xtlpkg
          kpsedev.tlpdb_pkgs << xtlpkg
        end
        add_package(kpsedev)
      end
      if kpselib
        if xtlpkg
          kpselib.tlpdb_pkgs << xtlpkg
        end
        add_package(kpselib)
      end
    end

    def create_package_from_tlpdb
      log.info "Creating package from tlpdb"
      app.tlpdb.each do |tlpkg|
        name = tlpkg.name.not_nil!

        pkgname = package_name_from_tlpdb_name(name)
        if pkgname.nil?
          log.debug { String.build { |x| x << "Skipping package " << name } }
          next
        end
        if (pkg = packages?(pkgname))
          log.info { "Adding #{name} to #{pkgname}" }
          pkg.tlpdb_pkgs << tlpkg
          next
        end

        log.info do
          String.build do |x|
            x << "Creating package " << pkgname << " of " << name
          end
        end

        add_package(Package.new(pkgname, tlpdb_pkgs: [tlpkg]))
      end

      stat = false
      each_package do |pkg|
        tlpkgs = pkg.tlpdb_pkgs
        if (tlpkg = tlpkgs.first?)
          pkg.summary = tlpkg.shortdesc
        end
        pkg.archdep = tlpkgs.any? do |tlpkg|
          binfiles = tlpkg.binfiles
          binfiles && !binfiles.empty?
        end
        pkg.description = String.build do |io|
          tlpkgs.each do |tlpkg|
            io << tlpkg.longdesc << "\n"
          end
        end
        tlpkgs.each do |tlpkg|
          if (ctan_license = tlpkg.catalogue_license)
            if (lics = parse_license(tlpkg, ctan_license))
              if lics.responds_to?(:each)
                lics.each do |lic|
                  pkg.license << lic
                end
              else
                pkg.license << lics
              end
            else
              stat = true
            end
          end
        end
        log.info do
          String.build do |io|
            io << "License of " << pkg.name << ": "
            f = false
            pkg.license.each do |lic|
              if f
                io << " and "
              end
              io << lic
              f = true
            end
          end
        end
      end
      if stat
        log.fatal { "Stopping by previous error(s). Please check." }
        exit 1
      end

      make_solib_package("kpathsea")
      make_solib_package("ptexenc", tlpkg: nil)

      if (fontutils = packages?("texlive-collection-fontutils"))
        fontutils.requires << "psutils"
        fontutils.requires << "t1utils"
      end

      add_package(Package.new("texlive-japanese-recommended",
                              summary: "TeX Live: recommended packages for Japanese users",
                              description: <<-EOD))
        This meta-package contains a collection of recommended packages for
        Japanese texlive users.
      EOD
    end

    def make_config_file(file : String)
      if file.starts_with?("texmf-dist/")
        File.join(TEXMFCONFIGDIR, file.sub("texmf-dist/", ""))
      elsif file.starts_with?("RELOC/")
        File.join(TEXMFCONFIGDIR, file.sub("RELOC/", ""))
      else
        File.join(TEXMFCONFIGDIR, file)
      end
    end

    def add_config_file(pkg : Package, path : String)
      cnffile = make_config_file(path)
      log.warn { "Creating in sysconfdir: #{cnffile}" }
      attr = FileAttribute.new(config: true)
      e = FileEntry.new(cnffile, attr: attr)
      pkg.files << e
    end

    def expand_tlpdb_files(pkg : Package, tlpkg : TLPDB::Package,
                           tag : TLPDB::Tag, files : TLPDB::Files)
      files.each do |pinfo|
        path = pinfo.path
        xpath = path
        doc = false
        skip = false
        pathparser = StringCase::Single.new(path)
        StringCase.strcase \
          case pathparser
          when "bin/"
            arch = pathparser.gets('/').not_nil!
            pos_save = pathparser.pos
            base = pathparser.gets_to_end
            pathparser.pos = pos_save
            xpath = File.join(BINDIR, base)
            StringCase.strcase \
              case pathparser
              when "man", "teckit_compile"
                skip = true
              end
          when "texmf-dist/", "RELOC/"
            pos_save = pathparser.pos
            xpath = File.join(TEXMFDIR, pathparser.gets.not_nil!)
            pathparser.pos = pos_save
            StringCase.strcase \
              case pathparser
              when "dvipdfm/config",
                   "dvipdfmx/dvipdfmx.cfg",
                   "dvips/config/config.ps",
                   "scripts/match_parens",
                   "scripts/mf2pt1",
                   "scripts/urlbst",
                   "tex/amstex/base/amsppt.sti",
                   "tex/generic/tex-ini-files/pdftexconfig.tex",
                   "tex/generic/config/language.def",
                   "tex/generic/config/language.dat.lua",
                   "tex/generic/config/language.dat",
                   "tex/lambda/config/language.dat",
                   "tex/mex/base/mexconf.cfg",
                   "tex/plain/cyrplain/cyrtex.cfg",
                   "web2c/fmtutil.cnf",
                   "web2c/mktex.cnf",
                   "web2c/texmf.cnf",
                   "web2c/texmfcnf.lua",
                   "web2c/updmap.cfg",
                   "xdvi/XDvi"
                add_config_file(pkg, path)
              when "doc/man/man1/install-tl.1",
                   "doc/man/man1/install-tl.man1.pdf"
                log.debug { "Skipping TLPKG file: #{path}" }
                skip = true
              end
          when "install-tl" # "tlpkg/",
            log.debug { "Skipping TLPKG file: #{path}" }
            skip = true
          when "tlpkg/"
            xpath = File.join(TEXMFDIR, xpath)
          when "release-texlive.txt",
               "README", "readme-txt.dir/", "readme-html.dir/",
               "LICENSE", "license", "doc.html", "index.html"
            log.debug { "Document: #{path}" }
            xpath = File.join(TEXMFDIR, xpath)
            doc = true
          else
            log.warn { "Unknown fullpath for: #{path}" }
          end

        if path.ends_with?(".exe") || path.ends_with?(".dll")
          log.debug { "Windows executable file: #{xpath}" }
          skip = true
        end
        case tag
        when TLPDB::Tag::DOCFILES
          doc = true
        end

        if skip
          log.warn { "Skipping file: #{xpath}" }
          next
        end

        entry = FileEntry.new(xpath, doc: doc, tlpdb_tag: tag)
        pkg.files << entry
      end
    end

    def create_file_entries
      @tree.clear

      tl_fs_pkg = Package.new("texlive-filesystem")
      TEXMF.each do |texmfdir|
        node = @tree.mkdir(texmfdir)
        tl_fs_pkg.files << FileEntry.new(texmfdir, dir: true)
        node.package = tl_fs_pkg
      end

      log.info "Creating package file entries"
      each_package do |pkg|
        pkg.tlpdb_pkgs.each do |tlpkg|
          {% for name, val in TLPDB::ALL_TAGS_DATA %}
            {% if val[:type] == :files %}
              files = tlpkg.{{val[:var_symbol].id}}
              if files
                expand_tlpdb_files(pkg, tlpkg,
                                   TLPDB::Tag::{{val[:const_symbol].id}},
                                   files)
              end
            {% end %}
          {% end %}
        end
        pkg.files.each do |entry|
          e = @tree.insert(entry.path)
          e.package = pkg
        end
      end

      log.info "Directory compacting"
      dirs = [] of DirectoryNode
      filesystem_pkg = Package.new("filesystem")
      RPM.transaction do |ts|
        iter = ts.init_iterator(RPM::DbiTag::Name, "filesystem")
        begin
          rpmfspkg = iter.first
          rpmfspkg.files.each do |entry|
            if (ent = @tree[entry.path]?)
              ent.package = filesystem_pkg
            end
          end
        ensure
          iter.finalize
        end
      end

      nil_pkg = Package.new("nil-package")
      @tree.each_entry_breadth.to_a.reverse_each do |entry|
        if entry.is_a?(DirectoryNode)
          pkg = entry.package
          if pkg
            pkg.files << FileEntry.new(entry.path, dir: true)
          else
            if entry.entries.size == 0
              log.warn { "Empty directry: #{entry.path}" }
            else
              log.fatal do
                String.build do |str|
                  str << "Non-empty directory `"
                  str << entry.path << "` found without any package"
                end
              end
              pkg.not_nil!
            end
          end
        end
        parent = entry.parent
        log.debug do
          String.build do |io|
            io << parent.path << ": "
            if (pkg = parent.package)
              io << pkg.name
            else
              io << "(not set)"
            end
          end
        end

        if parent.package.nil?
          if entry.package
            parent.package = entry.package
          else
            parent.package = nil_pkg
          end
        elsif parent.package != entry.package
          if parent.package != filesystem_pkg &&
             parent.package != nil_pkg
            parent.package = tl_fs_pkg
          end
        end
      end

      @tree.each_entry_breadth do |entry|
        pkg = entry.package
        if pkg && pkg != tl_fs_pkg && (pkg = packages?(pkg.name))
          while (parent = entry.parent) != entry
            if (dirpkg = parent.package)
              if dirpkg != pkg && packages?(dirpkg)
                dirpkg.requires << pkg.name
              end
            end
            entry = parent
          end
        end
      end

      tl_fs_pkg.summary = "TeX Live filesystem"
      tl_fs_pkg.description = "TeX Live filesystem"
      add_package(tl_fs_pkg)

      @tree.each_entry_recursive do |entry|
        if !entry.package
          log.error do
            String.build do |io|
              io << "`" << entry.path << "'"
              if entry.dir?
                io << " (directory)"
              else
                io << " (file)"
              end
              io << " is not contained by a package"
            end
          end
        end
      end
    end

    def create_file_tree
      File.open("texlive.filetree", "w") do |x|
        x.print @tree
      end
    end

    def adjust_dependency
      deptree = DependencyTree.new(app)
      each_package do |pkg|
        deptree.add(pkg)
      end
      deptree.unresolved_tlpkg_deps.each do |name, set|
        log.warn { "No package provides TL package '#{name}'" }
        set.each do |node|
          log.warn { "   ... required by '#{node.package.name}'" }
        end
      end
      deptree.db.each_value do |node|
        from = node.package
        node.depends.each do |dep|
          from.requires << dep.name
        end
      end

      each_package do |pkg|
        if pkg.files.empty? && pkg.requires.empty?
          log.warn { "#{pkg.name} does not require any other package and does not contain any files" }
        end
      end
    end

    def obsolete_old_packages
      log.info { "Creating obsoletion entries" }
      each_package do |pkg|
        name = pkg.name
        log.info { "Searching obsoletion info for #{name}" }
        pkg.files.each do |entry|
          next if entry.dir?
          installed_pkgs = installed_path_package(entry.path)
          if installed_pkgs.empty? && entry.tlpdb_tag == TLPDB::Tag::RUNFILES
            basename = File.basename(entry.path)
            paths = installed_file_path(basename)
            paths.delete_if do |path|
              if path.starts_with?(File.join(TEXMFDISTDIR, "doc"))
                true
              elsif path.starts_with?(File.join(TEXMFDIR, "doc"))
                true
              elsif path.starts_with?(TEXMFDISTDIR)
                false
              elsif path.starts_with?(TEXMFDIR)
                false
              else
                true
              end
            end
            paths.each do |path|
              log.debug { " --> #{path}" }
            end
            path = paths.first?
            if path
              log.warn { "Using '#{path}' for providing '#{entry.path}'" }
              installed_pkgs = installed_path_package(path)
            end
          end
          installed_pkgs.each do |x, rpmpkg|
            if rpmpkg.name != pkg.name
              v = rpmpkg[RPM::Tag::Version].as(String)
              r = rpmpkg[RPM::Tag::Release].as(String)
              e = rpmpkg[RPM::Tag::Epoch].as(UInt32?)
              vre = RPM::Version.new(v, r, e).to_vre
              if !pkg.obsoletes.any? do |x|
                   if x.responds_to?(:name)
                     x.name == rpmpkg.name
                   else
                     x == rpmpkg.name
                   end
                 end
                log.info do
                  " ... obsoletes: #{rpmpkg.name}-#{vre}"
                end
                pkg.obsoletes << rpmpkg
              end
            end
            rpmpkg.obsoletes.each do |obso|
              name = obso.name
              next if name == pkg.name
              next if pkg.obsoletes.any? do |x|
                        if x.responds_to?(:name)
                          x.name == name
                        else
                          x == name
                        end
                      end
              dnevr = obso.to_dnevr
              log.info do
                " ... obsoletes: #{dnevr}"
              end
              pkg.obsoletes << obso
            end
          end
        end
      end

      # Special obsoletes
      if (xdvi = packages?("texlive-xdvi"))
        if (pxdvi = installed_pkgs["texlive-pxdvik"]?)
          pxdvi_pkg = pxdvi.each_value.first
          log.info { "#{xdvi.name} obsoletes #{pxdvi_pkg.name}" }
          xdvi.obsoletes << pxdvi_pkg
        end
      end
    end

    def check_obsoletes
      log.info { "Finding packages which won't be obsoleted..." }
      scheme_full = packages("texlive-scheme-full")
      dset = installed_db.each_base_package.to_set
      cset = installed_db.each_base_package.to_set
      obsoleted_by = {} of String => Set(Package)
      each_package do |pkg|
        dset.delete_if do |opkg|
          pkg.name == opkg.name
        end
        rem = [] of (String | RPM::Package | RPM::Dependency)
        pkg.obsoletes.each do |obso|
          if obso.responds_to?(:name)
            name = obso.name
          else
            name = obso
          end
          dset.delete_if do |opkg|
            name == opkg.name
          end
          m = cset.find do |opkg|
            name == opkg.name
          end
          if m.nil?
            ipkg = nil
            RPM.transaction do |ts|
              iter = ts.init_iterator(RPM::DbiTag::Name, name)
              ipkg = iter.first?
            end
            if ipkg
              log.warn { "Unexpected obsoletes: #{name} by #{pkg.name}" }
              rem << obso
            end
          end
        end
        rem.each do |obso|
          pkg.obsoletes.delete(obso)
        end
        pkg.obsoletes.each do |obso|
          if obso.responds_to?(:name)
            name = obso.name
          else
            name = obso
          end
          if (entry = obsoleted_by[name]?)
            entry.add(pkg)
          else
            obsoleted_by[name] = Set{pkg}
          end
        end
      end
      h = {} of String => RPM::Package
      dset.each do |pkg|
        h[pkg.name] = pkg
      end
      h.each do |name, pkg|
        v = pkg[RPM::Tag::Version].as(String)
        r = pkg[RPM::Tag::Release].as(String)
        e = pkg[RPM::Tag::Epoch].as(UInt32?)
        vre = RPM::Version.new(v, r, e).to_vre
        log.warn { "Nothing obsoletes #{pkg.name}-#{vre}" }
        scheme_full.obsoletes << pkg
      end
      scheme_full.obsoletes << RPM::Obsolete.new("texlive-all", RPM::Version.new("2019", "0m"), RPM::Sense::LESS, nil)

      newtljap = packages("texlive-japanese-recommended")
      RPM.transaction do |ts|
        iter = ts.init_iterator(RPM::DbiTag::Name, "texlive-japanese-recommended")
        tljap = iter.first?
        if tljap
          log.info { "'texlive-japanese-recommended' will install:" }
          tljap.requires.each do |req|
            name = req.name
            if (whatobsoletes = obsoleted_by[name]?)
              whatobsoletes.each do |provider|
                pname = provider.name
                if !newtljap.requires.any? do |x|
                     pname == x
                   end
                  log.info { "  * #{pname}" }
                  newtljap.requires << pname
                end
              end
            elsif (whatprovides = packages?(name))
              if !newtljap.requires.any? do |x|
                   name == x
                 end
                log.info { "  * #{name}" }
                newtljap.requires << name
              end
            else
              log.warn { "  ... Nothing found which provides #{name}" }
            end
          end
          log.info { "(end)" }
        end
      end
    end

    def collect
      create_package_from_tlpdb
      create_file_entries
      adjust_dependency
      create_file_tree
      obsolete_old_packages
      check_obsoletes
    end
  end
end
