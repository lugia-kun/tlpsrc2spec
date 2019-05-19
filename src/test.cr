require "./strcase"

foo = StringCase::Single.new("foo")
StringCase.strcase_complete case foo
                            when "fa"
                              1
                            when "fabt"
                              2
                            else
                              3
                            end
