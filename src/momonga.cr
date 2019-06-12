require "./strcase"

# {% if compare_versions(Crystal::VERSION, "0.28.999999") < 0 %}
#   # Monkey-Patching Set.
#   struct Set(T)
#     def delete_if(&block)
#       @hash.delete_if do |*args|
#         yield *args
#       end
#     end
#   end
# {% end %}

module TLpsrc2spec
  class MomongaRule < Rule
    class Package < TLpsrc2spec::Package
      def group
        super || "Applications/Publishing"
      end
    end

    TEXMFDIR       = File.join(DATADIR, "texmf")
    TEXMFDISTDIR   = File.join(DATADIR, "texmf-dist")
    TEXMFLOCALDIR  = File.join(DATADIR, "texmf-local")
    TEXMFVARDIR    = File.join(LOCALSTATEDIR, "texmf")
    TEXMFCONFIGDIR = File.join(SYSCONFDIR, "texmf")
    TEXMF          = [TEXMFDIR, TEXMFDISTDIR, TEXMFLOCALDIR, TEXMFVARDIR, TEXMFCONFIGDIR]
    @tree : DirectoryTree
    @master : Package
    @all_license : Set(String) = Set(String).new
    @ts : RPM::Transaction = RPM::Transaction.new

    def initialize(*args)
      @tree = DirectoryTree.new
      @master = Package.new("texlive")
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
          filessets = tlpkg.{{val[:var_symbol].id}}
          filessets.each do |files|
            files.each do |x|
              io = StringCase::Single.new(x.path)
              # File.basename(x)
              ps = 0
              while (ch = io.next_char)
                if ch == '/'
                  ps = io.pos
                end
              end
              io.pos = ps
              StringCase.strcase_case_insensitive \
                case io
                when "COPYING", "LICENSE", "LICENCE",
                     "GUST-FONT-LICENSE", "GUST-FONT-LICENCE",
                     "GUST-FONT-NOSOURCE-LICENSE",
                     "GUST-FONT-NOSOURCE-LICENCE",
                     "COPYRIGHT", "IPA_Font_License_Agreement"
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
          log.debug { " * #{cand.path} (#{cand.details})" }
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
        when "bbm"
          # See https://ctan.org/pkg/bbm
          log.warn { "License of bbm unknown" }
          return "see \"README\""
        when "bbold-type1"
          # See https://ctan.org/pkg/bbold-type1
          return "see \"README\""
        when "beamertheme-metropolis"
          # See https://ctan.org/tex-archive/macros/latex/contrib/beamer-contrib/themes/metropolis
          # CC-BY-SA 4.0 International
          return "CC-BY-SA"
        when "berenisadf"
          # See https://ctan.org/tex-archive/fonts/berenisadf
          return ["GPLv2", "see \"COPYING\", LPPL"]
          # when "blacklettert1"
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
        when "coursepaper"
          # See https://ctan.org/tex-archive/macros/latex/contrib/coursepaper
          # NOTE: courcepaper.cls uses CR for line-terminator.
          return "see \"coursepaper.cls\""
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
        when "lshort-german"
          # See https://ctan.org/pkg/lshort-german
          # The full-text license is not included.
          return "see \"README.l2kurz\""
        when "lshort-spanish"
          # See https://ctan.org/pkg/lshort-spanish
          log.warn { "License of lshort-spanish unknown" }
          return "see \"LEAME.utf8\""
        when "lshort-ukr"
          # See https://ctan.org/pkg/lshort-ukr
          # This file is included in the tarball
          log.warn { "License of lshort-ukr unknown" }
          return "see \"README\""
        when "luaxml"
          # See https://ctan.org/pkg/luaxml
          # The full-text file not included
          #
          # The License of Lua changed at Lua 5.0 release. So "Lua
          # license" is ambiguous, and we assumed the luaxml's author
          # followed the change.
          #
          # return "\"Lua\""
          return "MIT"
        when "magaz"
          # See https://ctan.org/pkg/magaz
          return "see \"magaz.sty\""
        when "makeindex"
          # See https://ctan.org/pkg/makeindexk
          # The file is not included in the package
          return "see \"COPYING\""
        when "math-into-latex-4"
          # See https://ctan.org/pkg/math-into-latex-4
          return "see \"README\""
        when "mdputu"
          # See https://ctan.org/pkg/mdputu
          return "see \"mdputu.dtx\""
        when "menu"
          # See https://ctan.org/pkg/menu
          return "LPPL"
        when "metapost-examples"
          # See https://ctan.org/pkg/metapost-examples
          # Seems not to satisfy the application condition of GPL.
          return "GPL"
        when "midnight"
          # See https://ctan.org/pkg/midnight
          return "see \"README\""
        when "mkgrkindex"
          # See https://ctan.org/pkg/greek-makeindex
          return "LPPL"
        when "mpman-ru"
          # See https://ctan.org/pkg/mpman-ru
          log.warn { "License of mpman-ru unknown" }
          return "see \"README\""
        when "mslapa"
          # See https://ctan.org/pkg/mslapa
          return "see \"README\""
        when "nar"
          # See https://ctan.org/pkg/nar
          return "see \"nar.bst\""
        when "nestquot"
          # See https://ctan.org/pkg/nestquot
          return "see \"nestquot.sty\""
        when "newsletr"
          # See https://ctan.org/pkg/newsletr
          return "see \"README\""
        when "nimbus15"
          # See https://ctan.org/pkg/nimbus15
          return "AGPLv3"
        when "ocr-b", "ocr-b-outline"
          # See https://ctan.org/pkg/ocr-b
          # See https://ctan.org/pkg/ocr-b-outline
          return "see \"README\""
        when "oubraces"
          # See https://ctan.org/pkg/oubraces
          return "see \"oubraces.sty\""
        when "passivetex"
          # See https://ctan.org/pkg/passivetex
          return "see \"fotex.sty\""
        when "path"
          # See https://ctan.org/pkg/path
          return "see \"path.sty\""
        when "pictexsum"
          # See https://ctan.org/pkg/pictexsum
          return "see \"README\""
        when "pkuthss"
          # See https://ctan.org/pkg/pkuthss
          return "see \"README\""
        when "plweb"
          # See https://ctan.org/pkg/pl
          return "see \"pl.dtx\""
        when "pnas2009"
          # See https://ctan.org/pkg/pnas2009
          return "see \"pnas2009.bst\""
        when "productbox"
          # See https://ctan.org/pkg/productbox
          return "see \"README\""
        when "ps2pk"
          # See https://ctan.org/pkg/ps2pk
          log.warn { "License of ps2pk unknown" }
          return "see \"README\""
        when "psfrag"
          # See https://ctan.org/pkg/psfrag
          return "see \"psfrag.dtx\""
        when "ptex"
          # See https://ctan.org/pkg/ptex
          # This file is not included.
          return "see \"COPYRIGHT\""
        when "punknova"
          # See https://ctan.org/pkg/punknova
          return "see \"README\""
        when "r_und_s"
          # See https://ctan.org/pkg/r_und_s
          return "see \"README\""
        when "rsfs"
          # See https://ctan.org/pkg/rsfs
          return "see \"README\""
        when "seetexk"
          # See https://ctan.org/pkg/dvibook
          log.warn { "License of dvibook unknown" }
          return "see \"README\""
        when "slideshow"
          # See https://ctan.org/pkg/slideshow
          return "see \"slideshow.mp\""
        when "sort-by-letters"
          # See https://ctan.org/pkg/sort-by-letters
          return "see \"README\""
        when "sphack"
          # See https://ctan.org/pkg/sphack
          return "see \"sphack.sty\""
        when "tabls"
          # See https://ctan.org/pkg/tabls
          return "see \"tabls.sty\""
        when "tds"
          # See https://ctan.org/pkg/tds
          return "see \"README\""
        when "tetex"
          log.warn { "License of tetex is incomplete" }
          return ["LGPL2+"]
        when "tex-refs"
          # See https://ctan.org/pkg/tex-references
          # This does not satisfy the application condition of GFDL.
          return "GFDL"
        when "threeparttable"
          # See https://ctan.org/pkg/threeparttable
          return "see \"threeparttable.sty\""
        when "tie"
          # See https://ctan.org/pkg/tie
          log.warn { "License of tie unkown" }
          return "see \"README\""
        when "tikz-dimline"
          # See https://ctan.org/pkg/tikz-dimline
          # The full-text file is not included.
          return "\"WTFPL\""
        when "trigonometry"
          # See https://ctan.org/pkg/trigonometry
          return "see \"README.txt\""
        when "tucv"
          # See https://ctan.org/pkg/tucv
          # The full-text file is not included.
          return "CC-BY-SA"
        when "tugboat-plain"
          # See https://ctan.org/pkg/tugboat-plain
          return "see \"tugboat.sty\""
        when "ulem"
          # See https://ctan.org/pkg/ulem
          return "see \"README\""
        when "undergradmath"
          # See https://ctan.org/pkg/undergradmath
          # The full-text license file is not included.
          return "CC-BY-SA"
        when "uppunctlm"
          # See https://ctan.org/pkg/uppunctlm
          # File not included
          return "see \"GUST-FONT-LICENSE.txt\""
        when "uspace"
          # See https://ctan.org/pkg/uspace
          return "MIT"
        when "variablelm"
          # See https://ctan.org/pkg/variablelm
          # File not included
          return "see \"GUST-FONT-LICENSE.txt\""
        when "venturisadf"
          # See https://ctan.org/pkg/venturisadf
          return "LPPL"
        when "version"
          # See https://ctan.org/pkg/version
          return "see \"version.sty\""
        when "vntex"
          # See https://ctan.org/pkg/vntex
          return [
            "GPL",
            "LGPL",
            "LPPL",
            "see \"LICENSE-utopia.txt\"",
          ]
        when "wadalab"
          # See https://ctan.org/pkg/wadalab
          return "see \"README\""
        when "webguide"
          # See https://ctan.org/pkg/webguide
          return "see \"README\""
        when "xcharter"
          # See https://ctan.org/pkg/xcharter
          return [
            "see \"README\"",
            "LPPL",
          ]
        when "xdvi"
          # See https://ctan.org/pkg/xdvi
          log.warn { "License of xdvi unknown" }
          return "see \"README\""
        when "yfonts-t1"
          # See https://ctan.org/pkg/yfonts-t1
          log.warn { "License of yfonts-t1 unknown" }
          return "see \"README\""
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
            "LPPL",
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
            "see \"COPYING\"", # blacklettert1
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
            when "nd-1", "nd-2", "nd-3", "nd-4"
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
              dirs = {include_subdir}
            end
          else
            dirs = {"*"}
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
                {{n.id}}: [] of TLPDB::Files,
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
        pkg.archdep = tlpkgs.any? do |tlpkg|
          binfiles = tlpkg.binfiles
          binfiles && !binfiles.empty?
        end
        archdepname = nil
        if (tlpkg = tlpkgs.first?)
          if pkg.archdep?
            n = tlpkg.name.not_nil!
            ni = n.byte_index('.'.ord)
            archdepname = n[0...ni]
            pkg.summary = String.build do |io|
              io << "Binary files for TeX Live Package '"
              io << archdepname
              io << "'"
            end
          else
            if (sdesc = tlpkg.shortdesc)
              pkg.summary = sdesc.gsub('%', "%%")
            else
              name = tlpkg.name.not_nil!
              log.warn { "Package #{name} has not shortdesc" }
              pkg.summary = String.build do |io|
                io << "TeX Live Package: " << name
              end
            end
          end
        end
        pkg.description = String.build do |io|
          if pkg.archdep?
            io << "Binary files for TeX Live Package '"
            io << archdepname.not_nil!
            io << "'"
          else
            nlongdesc = tlpkgs.count do |tlpkg|
              l = tlpkg.longdesc
              l && l.size > 0
            end
            print_name = nlongdesc > 1
            first = true
            tlpkgs.each do |tlpkg|
              longdesc = tlpkg.longdesc
              if !longdesc || longdesc.size == 0
                next
              end
              longdesc = longdesc.gsub('%', "%%")
              if print_name
                if !first
                  io << "\n"
                end
                io << "(" << tlpkg.name << ")\n"
              end
              io << longdesc << "\n"
              first = false
            end
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
      each_package do |pkg|
        pkg.license.each do |lic|
          if lic.starts_with?("see ")
            @all_license.add("see \"LICENSE\"")
          else
            @all_license.add(lic)
          end
        end
      end
      if @all_license.empty?
        log.warn("No license information collected, using just LPPL instead.")
        @all_license.add("LPPL")
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

    def add_config_file(pkg : TLpsrc2spec::Package, path : String)
      cnffile = make_config_file(path)
      log.warn { "Creating in sysconfdir: #{cnffile}" }
      conf = FileConfig.new
      e = FileEntry.new(cnffile, config: conf)
      pkg.files << e
    end

    def expand_tlpdb_files(pkg : TLpsrc2spec::Package, tlpkg : TLPDB::Package,
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
              filessets = tlpkg.{{val[:var_symbol].id}}
              filessets.each do |files|
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
      # RPM.transaction do |ts|
      begin
        iter = @ts.init_iterator(RPM::DbiTag::Name, "filesystem")
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
        # log.debug do
        #   String.build do |io|
        #     io << parent.path << ": "
        #     if (pkg = parent.package)
        #       io << pkg.name
        #     else
        #       io << "(not set)"
        #     end
        #   end
        # end

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

    def make_obsolete(rpmpkg : RPM::Package)
      v = rpmpkg[RPM::Tag::Version].as(String)
      r = rpmpkg[RPM::Tag::Release].as(String)
      e = rpmpkg[RPM::Tag::Epoch].as(UInt32?)
      version = RPM::Version.new(v, r, e)
      RPM::Obsolete.new(rpmpkg.name, version,
        RPM::Sense::LESS | RPM::Sense::EQUAL, nil)
    end

    def obsolete_old_packages
      log.info { "Creating obsoletion entries" }
      metadirs = [TEXMFDISTDIR, TEXMFDIR]
      docdirs = metadirs.map { |x| File.join(x, "doc") }
      each_package do |pkg|
        name = pkg.name
        log.info { "Searching obsoletion info for #{name}" }
        pkg.files.each do |entry|
          next if entry.dir?
          installed_pkgs = installed_path_package(entry.path)
          if installed_pkgs.empty? &&
             (entry.tlpdb_tag == TLPDB::Tag::RUNFILES ||
             entry.tlpdb_tag == TLPDB::Tag::DOCFILES)
            basename = File.basename(entry.path)
            paths = installed_file_path(basename)
            if entry.tlpdb_tag == TLPDB::Tag::RUNFILES
              filter = Proc(String, Bool).new do |path|
                if docdirs.any? { |dir| path.starts_with?(dir) }
                  true
                elsif metadirs.any? { |dir| path.starts_with?(dir) }
                  false
                else
                  true
                end
              end
            else
              filter = Proc(String, Bool).new do |path|
                if docdirs.any? { |dir| path.starts_with?(dir) }
                  false
                else
                  true
                end
              end
            end
            pathparts = Path.new(entry.path).parts
            h_map = paths.compact_map do |path|
              if filter.call(path)
                nil
              else
                xparts = Path.new(path).parts
                a = pathparts.reverse_each
                b = xparts.reverse_each
                i = 0
                aa = ""
                bb = ""
                while aa == bb
                  aa = a.next
                  bb = b.next
                  if aa.is_a?(Iterator::Stop) || bb.is_a?(Iterator::Stop)
                    break
                  end
                  i += 1
                end
                {path, i}
              end
            end
            found = nil
            if h_map.size > 0
              found = h_map.max_by do |ent|
                ent[1]
              end
            end
            h_map.each do |ent|
              log.debug do
                String.build do |builder|
                  builder << " --> "
                  if found && ent[0] == found[0]
                    builder << "* "
                  else
                    builder << "  "
                  end
                  builder << ent[0] << " (score: " << ent[1] << ")"
                end
              end
            end
            path = nil
            if found
              if found[1] <= 3
                basename = StringCase::Single.new(found[0])
                xpos = 0
                until basename.eof?
                  ch = basename.next_char
                  if ch == '/'
                    xpos = basename.pos
                  end
                end
                basename.pos = xpos
                StringCase.strcase_case_insensitive \
                  case basename
                # README and common names
                when "README", "LICENSE", "LICENCE", "COPYING",
                     "COPYRIGHT", "CHANGES", "VERSION", "ChangeLog",
                     "INSTALL", "ABOUT", "NEWS", "THANKS", "TODO",
                     "AUTHORS", "BACKLOG", "FONTLOG", "FAQ",
                     "NOTICE", "00readme"
                  nil
                  # License filename
                when "OFL", "GPL"
                  nil
                  # for aastex
                when "natnotes.tex"
                  nil
                  # for afparticle
                when "vitruvian.jpg"
                  nil
                  # for ametstoc
                when "template.tex"
                  nil
                  # for changebar
                when "cbtest1.tex"
                  nil
                  # for background
                when "background.pdf"
                  nil
                  # for classisthesis
                when "abstract.tex"
                  nil
                  # for lshort etc.
                when "title.tex"
                  nil
                  # for ketcindy
                when "fourier.tex"
                  nil
                  # for fascicules
                when "tikz.tex"
                  nil
                  # for url
                when "miscdoc.sty"
                  nil
                  # maven
                when "build.xml"
                  nil
                  # generic names used by many packages.
                when "exmaple.pdf", "example.tex", "sample.pdf",
                     "sample.tex", "layout.pdf",
                     "appendix", "grid.tex", "chart.tex", "test.tex",
                     "alea.tex", "fill.tex", "ltxdoc.cfg", "minimal.tex",
                     "at.pdf", "references.bib", "manifest", "logo.pdf",
                     "help.tex", "guide.pdf", "preamble.tex", "intro.tex"
                  nil
                else
                  path = found[0]
                end
              else
                path = found[0]
              end
            end
            if path
              log.debug { "Using path   '#{path}'" }
              log.debug { "... provides '#{entry.path}'" }
              installed_pkgs = installed_path_package(path)
            end
          end
          installed_pkgs.each do |x, rpmpkg|
            if rpmpkg.name != pkg.name
              if !pkg.obsoletes.any? do |x|
                   if x.responds_to?(:name)
                     x.name == rpmpkg.name
                   else
                     x == rpmpkg.name
                   end
                 end
                obso = make_obsolete(rpmpkg)
                log.info do
                  String.build do |str|
                    str << " ... obsoletes: "
                    str << obso.name << "-" << obso.version.to_vre
                    if path
                      str << " (by file '"
                      str << path
                      str << "' which will be replaced by '"
                      str << entry.path
                      str << "')"
                    else
                      str << " (by file '"
                      str << entry.path
                      str << "')"
                    end
                  end
                end
                pkg.obsoletes << obso
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
                " ... obsoletes: #{dnevr} (by package #{rpmpkg.name})"
              end
              pkg.obsoletes << obso
            end
          end
        end
      end

      # Special obsoletes
      if (xdvi = packages?("texlive-xdvi")) &&
         (pxdvi = installed_pkgs["texlive-pxdvik"]?)
        pxdvi_pkg = pxdvi.each_value.first
        log.info { "#{xdvi.name} obsoletes #{pxdvi_pkg.name}" }
        xdvi.obsoletes << make_obsolete(pxdvi_pkg)
      end
    end

    def check_obsoletes
      log.info { "Finding packages which won't be obsoleted..." }
      scheme_full = packages("texlive-scheme-full")
      cset = installed_db.each_base_package.to_set
      obsoleted_by = {} of String => Set(TLpsrc2spec::Package)
      found_obsoletes = Set(String).new
      each_package do |pkg|
        found_obsoletes.add(pkg.name)
        rem = [] of (String | RPM::Dependency)
        pkg.obsoletes.each do |obso|
          if obso.responds_to?(:name)
            name = obso.name
          else
            name = obso
          end
          found_obsoletes.add(name)
          m = cset.find do |opkg|
            name == opkg.name
          end
          if m.nil?
            ipkg = nil
            # RPM.transaction do |ts|
            begin
              iter = @ts.init_iterator(RPM::DbiTag::Name, name)
              begin
                ipkg = iter.first?
              ensure
                iter.finalize
              end
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
      dset = installed_db.each_base_package
      dset.each do |pkg|
        if found_obsoletes.includes?(pkg.name)
          next
        end
        obso = make_obsolete(pkg)
        log.warn { "Nothing obsoletes #{obso.name}-#{obso.version.to_vre}" }
        scheme_full.obsoletes << obso
      end
      scheme_full.obsoletes << RPM::Obsolete.new("texlive-all", RPM::Version.new("2019"), RPM::Sense::LESS, nil)

      log.info { "Reverse obsoletion info" }
      obsoleted_by.each do |name, pkgs|
        if pkgs.size > 0
          log.info { "'#{name}' will be obsoleted by:" }
          pkgs.each do |pkg|
            log.info { " * #{pkg.name}" }
          end
        end
      end

      newtljap = packages("texlive-japanese-recommended")
      # RPM.transaction do |ts|
      begin
        iter = @ts.init_iterator(RPM::DbiTag::Name, "texlive-japanese-recommended")
        begin
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
              elsif !name.starts_with?("rpmlib")
                log.warn { "  ... Nothing found which provides #{name}" }
              end
            end
            log.info { "(end)" }
          end
        ensure
          iter.finalize
        end
      end
    end

    def set_master_info
      @master.summary = "The TeX Live text formatting system"
      @master.description = <<-EOD
      The TeX Live software distribution offers a complete TeX system for a
      variety of Unix, Macintosh, Windows and other platforms. It
      encompasses programs for editing, typesetting, previewing and printing
      of TeX documents in many different languages, and a large collection
      of TeX macros and font libraries.

      The distribution includes extensive general documentation about TeX,
      as well as the documentation for the included software packages.
      EOD
      @master.url = "http://www.tug.org/texlive/"
      @master.version = "2019"
      @master.release = "%{momorel}m%{dist}"

      # Use LPPL as a mandatory license.
      license = Set{"LPPL"}
      io = StringCase::Single.new(64)
      each_package do |pkg|
        pkg.license.each do |lic|
          io.print lic
          io.pos = 0
          StringCase.strcase \
            case io
          when "see \""
            license.add "see \"LICENSE\""
          else
            license.add lic
          end
          io.clear
        end
      end
      @master.license = license.to_a
    end

    def adjust_file_path
      each_package do |pkg|
        pkg.files.each do |entry|
          path = entry.path
          [
            {TEXMFDIR, "%{_texmfdir}"},
            {TEXMFDISTDIR, "%{_texmfdir}"},
            {TEXMFVARDIR, "%{_texmfvardir}"},
            {TEXMFCONFIGDIR, "%{_texmfconfigdir}"},
            {BINDIR, "%{_bindir}"},
            {LIBDIR, "%{_libdir}"},
            {INCLUDEDIR, "%{_includedir}"},
            {SYSCONFDIR, "%{_sysconfdir}"},
            {SHAREDSTATEDIR, "%{_sharedstatedir}"},
            {MANDIR, "%{_mandir}"},
            {DATADIR, "%{_datadir}"},
          ].each do |mfpath, repl|
            if path.starts_with?(mfpath)
              entry.path = path.sub(mfpath, repl)
              break
            end
          end
        end
      end
    end

    def add_script
      each_package do |pkg|
        mktexlsr = false
        updmap = [] of String
        fmtutil = [] of String
      end
    end

    def collect
      create_package_from_tlpdb
      create_file_entries
      adjust_dependency
      create_file_tree
      obsolete_old_packages
      check_obsoletes
      adjust_file_path
      add_script
      set_master_info
    end

    def master_package
      @master
    end
  end
end
