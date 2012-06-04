require 'rubygems'
require 'parser2'
require 'json'

def load filename
  text = File.read(filename)
  input = JSON.parse(text)
  columns = input['columns']
  data = input['data']
  puts "#{filename}: #{data.length} rows x #{columns.length} columns"
  # puts columns.inspect
  # puts data[0].inspect
  return input
end

@functs = {}
@sheets = {}
@tables = {}
@columns = {}
@strings = {}
@numbers = {}
@undef = {}
@ref = {}

@dot = []
@formulas = {}
@parser = Parser.new

def quote string
  "\"#{string.to_s.gsub(/([a-z0-9]|GHG|MSW)[_ \/]*([A-Z])/,'\1\n\2')}\""
end

def eval from, expr
  return unless expr
  # puts "--#{expr.inspect}"
  case
  when s=expr[:sheet]
    label = expr[:absrow] && expr[:abscol] ? "[label=\"$\"]" : ""
    # label = "[label=\"#{[:abscol, :absrow].collect {|abs| expr[abs] ? "$" : "."}}\"]"
    @dot << "#{quote s} [fillcolor=white];" unless @columns[@sheets[s.to_s]]
    @dot << "#{quote from} -> #{quote s} #{label};"
    @sheets[s.to_s] = 1
  when r=expr[:absrow]||expr[:row]
    # nothing special yet
  when o=expr[:op]
    eval from, expr[:left]
    eval from, expr[:right]
  when o=expr[:opsp]
    eval from, expr[:left]
    eval from, expr[:right]
  when f=expr[:function]
    # @dot << "#{quote from} -> #{quote f};"
    @functs[f.to_s] = 1
    [expr[:args]].flatten.each {|arg| eval from, arg}
  when c=expr[:column]
    label = expr[:current] ? "[label=\"@\"]" : ""
    @dot << "#{quote c} [fillcolor=lightgray];" unless @columns[c.to_s]
    @dot << "#{quote from} -> #{quote c} #{label};" unless c=='Material'
    @dot << "#{quote expr[:table]} [shape=box]; #{quote c} -> #{quote expr[:table]};" if expr[:table]
    @columns[c.to_s] = 1
    @tables[expr[:table].to_s]=1 if expr[:table]
  when f=expr[:formula]
    @dot << "#{quote from} -> #{quote f};"
    # @formulas[f.to_s] = 1
    defn = @formulas[f.to_s]
    if defn
      @ref[f.to_s] = 1
      parse defn, f.to_s
    else
      @undef[f.to_s] = 1
    end
  when s=expr[:string]
    @strings[s.to_s] = 1
  when n=expr[:number]
    @numbers[n.to_s] = 1
  when b=expr[:boolean]
    @numbers[b.to_s] = 1
  else
    puts "Can't Eval:"
    puts JSON.pretty_generate(expr)
  end
end

@trouble = 0
def parse str, binding=''
  puts "---------------------\n#{binding}#{str}"
  expr = @parser.parse_excel str
  # puts JSON.pretty_generate(expr)
  eval binding, expr
rescue Parslet::ParseFailed => err
  @trouble += 1
  puts "trouble #{@trouble}: ", err, @parser.error_tree
end


# parse "=(10*(1-(-1.75179473531518E-15*Tier1Raw!G10^6 + 1.4557896802775E-12*Tier1Raw!G10^5 - 8.4072904671037E-11*Tier1Raw!G10^4 - 2.13762500849562E-07*Tier1Raw!G10^3 + 0.0000580307924400447*Tier1Raw!G10^2 - 0.000467308212137141*Tier1Raw!G10)))"

# parse "=IF(Tier1Raw!H11<0,15,IF(Tier1Raw!H11>17,(15*(1-(-0.0000323419744468201*Tier1Raw!H11^2 + 0.00646102566117069*Tier1Raw!H11 + 0.673902585769844))),(15*(1-(-0.00143091294220916*Tier1Raw!H11^2 + 0.0705541152858646*Tier1Raw!H11)))))"

# parse "=IFERROR(SUM(IF(([@TransportSenario]=Tier3TransportSenario[Scenario]),INDIRECT(\"Tier3TransportSenario[\"&[@ProcessType]&\"]\"))),0)"

# exit

# load("try8/Tier3Functions.json")['data'].each do |row|
#   parse row['Function'],row['Function Name']
# end

load("try8/Tier3Functions.json")['data'].each do |row|
  @formulas[row['Function Name']] = row['Function']
end

File.open('formulas.txt') do |file|
  dup = {}
  n = 0
  while (line = file.gets)
    (filename, column, formula) = line.chomp.split("\t")
    n += 1
    next if formula =~ /'C:/
    @dot << "#{quote filename} [shape=box fillcolor=white];\n#{quote filename} -> #{quote column}" unless dup["#{filename}-#{column}"]
    dup["#{filename}-#{column}"] = 1
    parse formula, column
  end
end

puts "\nsheets: #{@sheets.keys.inspect}"
puts "\nfuncts: #{@functs.keys.inspect}"
puts "\ntables: #{@tables.keys.inspect}"
puts "\ncolumns: #{@columns.keys.inspect}"
puts "\nstrings: #{@strings.keys.inspect}"
puts "\nnumbers: #{@numbers.keys.inspect}"
puts "\nundef: #{@undef.keys.inspect}"
puts "\nunref: #{(@formulas.keys - @ref.keys).inspect}"

File.open('formula-chart.dot', 'w') do |f|
  f.puts "strict digraph nmsi {\ngraph[aspect=5];\nnode[style=filled, fillcolor=gold];\n#{@dot.join("\n")}\n}"
end

puts "\n\n#{@trouble} trouble"