module Slaw
  module Parse
    module Bylaw
      class Bylaw < Treetop::Runtime::SyntaxNode
        def to_xml(b)
          b.act(contains: "originalVersion") { |b|
            b.meta { |b|
              b.identification(source: "#openbylaws") { |b|
                # TODO: correct values
                b.FRBRWork { |b|
                  b.FRBRthis(value: '/za/by-law/locale/1980/name/main')
                  b.FRBRuri(value: '/za/by-law/locale/1980/name')
                  b.FRBRalias(value: 'By-Law Short Title')
                  b.FRBRdate(date: '1980-01-01', name: 'Generation')
                  b.FRBRauthor(href: '#council', as: '#author')
                  b.FRBRcountry(value: 'za')
                }
                b.FRBRExpression { |b|
                  b.FRBRthis(value: '/za/by-law/locale/1980/name/main/eng@')
                  b.FRBRuri(value: '/za/by-law/locale/1980/name/eng@')
                  b.FRBRdate(date: '1980-01-01', name: 'Generation')
                  b.FRBRauthor(href: '#council', as: '#author')
                  b.FRBRlanguage(language: 'eng')
                }
                b.FRBRManifestation { |b|
                  b.FRBRthis(value: '/za/by-law/locale/1980/name/main/eng@')
                  b.FRBRuri(value: '/za/by-law/locale/1980/name/eng@')
                  b.FRBRdate(date: Time.now.strftime('%Y-%m-%d'), name: 'Generation')
                  b.FRBRauthor(href: '#openbylaws', as: '#author')
                }
              }

              b.publication(date: '1980-01-01',
                            name: 'Province of Western Cape: Provincial Gazette',
                            number: 'XXXX',
                            showAs: 'Province of Western Cape: Provincial Gazette')

              b.references(source: "#this") {
                b.TLCOrganization(id: 'openbylaws', href: 'http://openbylaws.org.za', showAs: "openbylaws.org.za")
                b.TLCOrganization(id: 'council', href: '/ontology/organization/za/council.cape-town', showAs: "Cape Town City Council")
                b.TLCRole(id: 'author', href: '/ontology/role/author', showAs: 'Author')
              }
            }

            if preamble.text_value != ""
              b.preamble { |b|
                preamble.to_xml(b)
              }
            end

            b.body { |b|
              chapters.elements.each { |e| e.to_xml(b) }
            }
          }
        end
      end

      class Preamble < Treetop::Runtime::SyntaxNode
        def to_xml(b)
          elements.each { |e|
            if not (e.content.text_value =~ /^preamble/i)
              b.p(e.content.text_value)
            end
          }
        end
      end

      class Part < Treetop::Runtime::SyntaxNode
        def num
          heading.empty? ? nil : heading.num
        end

        def to_xml(b)
          # do we have a part heading?
          if not heading.empty?
            id = "part-#{num}"

            # include a chapter number in the id if our parent has one
            if parent and parent.parent.is_a?(Chapter) and parent.parent.num
              id = "chapter-#{parent.parent.num}.#{id}"
            end

            b.part(id: id) { |b|
              heading.to_xml(b)
              sections.elements.each { |e| e.to_xml(b) }
            }
          else
            # no parts
            sections.elements.each { |e| e.to_xml(b) }
          end
        end
      end

      class PartHeading < Treetop::Runtime::SyntaxNode
        def num
          part_heading_prefix.alphanums.text_value
        end

        def title
          content.text_value
        end

        def to_xml(b)
          b.num(num)
          b.heading(title)
        end
      end

      class Chapter < Treetop::Runtime::SyntaxNode
        def num
          heading.empty? ? nil : heading.num
        end

        def to_xml(b)
          # do we have a chapter heading?
          if not heading.empty?
            id = "chapter-#{num}"

            # include a part number in the id if our parent has one
            if parent and parent.parent.is_a?(Part) and parent.parent.num
              id = "part-#{parent.parent.num}.#{id}"
            end

            b.chapter(id: id) { |b|
              heading.to_xml(b)
              parts.elements.each { |e| e.to_xml(b) }
            }
          else
            # no chapters
            parts.elements.each { |e| e.to_xml(b) }
          end
        end
      end

      class ChapterHeading < Treetop::Runtime::SyntaxNode
        def num
          chapter_heading_prefix.alphanums.text_value
        end

        def title
          content.text_value
        end

        def to_xml(b)
          b.num(num)
          b.heading(title)
        end
      end

      class Section < Treetop::Runtime::SyntaxNode
        def num
          section_title.num
        end

        def title
          section_title.title
        end

        def subsections
          section_content.elements
        end

        def to_xml(b)
          id = "section-#{num}"
          b.section(id: id) { |b|
            b.num("#{num}.")
            b.heading(title)

            idprefix = "#{id}."

            if definitions? and definitions
              definitions.to_xml(b, idprefix)
            else
              subsections.each_with_index { |e, i| e.to_xml(b, i, idprefix) }
            end
          }
        end

        # is this a definitions section?
        def definitions?
          title =~ /^definition|^interpretation/i
        end

        def definitions
          # Parse the definitions section using the definitions grammar
          begin
            @definitions ||= Slaw::Parse::Parser.new.parse_definitions(
                section_content.input[0...section_content.interval.last],
                index: section_content.interval.first)
          rescue Slaw::Parse::ParseError
            nil
          end
        end
      end

      class SectionTitleType1 < Treetop::Runtime::SyntaxNode
        # a section title of the form:
        #
        # Definitions
        # 1. In this by-law...

        def num
          section_title_prefix.number_letter.text_value
        end

        def title
          content.text_value
        end
      end

      class SectionTitleType2 < Treetop::Runtime::SyntaxNode
        # a section title of the form:
        #
        # 1. Definitions
        # In this by-law...
        #
        # In this format, the title is optional and the section content may
        # start where we think the title is.

        def num
          section_title_prefix.number_letter.text_value
        end

        def title
          section_title.empty? ? "" : section_title.content.text_value
        end
      end

      class Subsection < Treetop::Runtime::SyntaxNode
        def to_xml(b, i, idprefix)
          if statement.is_a?(NumberedStatement)
            attribs = {id: idprefix + statement.num.gsub(/[()]/, '')}
          else
            attribs = {id: idprefix + "subsection-#{i}"}
          end

          idprefix = attribs[:id] + "."

          b.subsection(attribs) { |b|
            b.num(statement.num) if statement.is_a?(NumberedStatement)
            
            b.content { |b| 
              if blocklist and blocklist.is_a?(Blocklist)
                if statement.content
                  blocklist.to_xml(b, i, idprefix) { |b| b << statement.content.text_value }
                else
                  blocklist.to_xml(b, i, idprefix)
                end
              else
                # raw content
                b.p(statement.content.text_value) if statement.content
              end
            }
          }
        end
      end

      class NumberedStatement < Treetop::Runtime::SyntaxNode
        def num
          numbered_statement_prefix.num.text_value
        end

        def parentheses?
          !numbered_statement_prefix.respond_to? :dotted_number_2
        end

        def content
          if elements[3].text_value == ""
            nil
          else
            elements[3].content
          end
        end
      end

      class NakedStatement < Treetop::Runtime::SyntaxNode
      end

      class Blocklist < Treetop::Runtime::SyntaxNode
        # Render a block list to xml. If a block is given,
        # yield to it a builder to insert a listIntroduction node
        def to_xml(b, i, idprefix, &block)
          id = idprefix + "list#{i}"
          idprefix = id + '.'

          b.blockList(id: id) { |b|
            b.listIntroduction { |b| yield b } if block_given?

            elements.each { |e| e.to_xml(b, idprefix) }
          }
        end
      end

      class BlocklistItem < Treetop::Runtime::SyntaxNode
        def num
          blocklist_item_prefix.text_value
        end

        def to_xml(b, idprefix)
          b.item(id: idprefix + num.gsub(/[()]/, '')) { |b|
            b.num(num)
            b.p(content.text_value)
          }
        end
      end

      class DefinitionsSection < Treetop::Runtime::SyntaxNode
        def to_xml(b, idprefix)
          b.list(id: "definitions") { |b| 
            b.intro { |b| b.p(content.text_value) }
            definitions.elements.each_with_index { |e, i| e.to_xml(b, i, idprefix) }
          }
        end
      end

      class Definition < Treetop::Runtime::SyntaxNode
        def term
          defined_term.text_value
        end

        def term_id
          @term_id ||= term.gsub(/[^a-zA-Z0-9_-]/, '_')
        end

        def to_xml(b, i, idprefix)
          id = "def-term-#{term_id}"
          b.point(id: id) { |b|

            b.subsection(id: id + ".subsection-0") { |b|
              b.content { |b| defn_xml(b) }
            }
            
            definition.elements.each_with_index do |child, i|
              section_id = id + ".subsection-#{i+1}"

              b.subsection(id: section_id) { |b|
                b.content { |b|
                  child.to_xml(b, i, section_id + ".")
                }
              }
            end
          }
        end

        def defn_xml(b)
          # "<def refersTo="#term-affected_land" id="adef-term-affected_land">affected land</def>" means land in respect of which an application has been lodged in terms of section 17(1);

          # use a supplemental builder to construct a tag without indentation
          s = ""
          b2 = Builder::XmlMarkup.new(target: s)
          b2 << '<p>"'
          b2.def(term, refersTo: "#term-#{term_id}")
          b2 << '"' + content.text_value
          b2 << '</p>'

          b << s
        end
      end

      class DefinitionStatement < Treetop::Runtime::SyntaxNode
        def to_xml(b, i, idprefix)
          b.p(content.text_value)
        end
      end
    end
  end
end
