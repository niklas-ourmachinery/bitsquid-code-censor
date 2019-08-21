require 'find'
require 'fileutils'

# Blanks out all lines that are inside an #if with the specified pre-processor tags.
#
# Sections that will be blanked:
#
#	#ifdef TAG
#	#if defined(TAG)
#	#elif defined(TAG)
#	#if defined(TAG) && OTHER_CONDITION && !THIRD_CONDITION
#	#if TAG
#	#if TAG // some comment										// C++ style comments are handled
#
# Sections that will not be blanked:
#
#	#ifndef TAG
#	#if !defined(TAG)
#	#if OTHER_CONDITION
#	#elseif OTHER_CONDITION
#	#else														// Raw else is never stripped, tag must be explicitly stated
#	#if defined(TAG) || OTHER_CONDITION || !THIRD_CONDITION
#	// #if TAG													// C++ style comments are handled
#	#if TAG /* comment */										// C style comments are handled if they open and close on the line
#	#if OTHER && BLA || KOKO >= 7								// Any complicated condition that doesn't include TAG
#
# Syntax that is not handled:
#
#	/* #ifdef TAG												// Unclosed C-style comments on same line as preprocessor command
#
# 
class StripTags
	# tags is a list of #ifdef tags that should be stripped from the files
	# If replace_tags is specified, the tags will be replaced with these tags when stripping
	def initialize(tags, replace_tags = nil)
		@tags = tags
		@replace_tags = replace_tags || tags
	end
	
	# Filters the text s, returns a new text with the tags stripped out
	# If file is specified it will be used for error messages
	def filter(s, file = nil)
		state = State.new([], "", false)
		state.file = file
		state.line_number = 0
		s.each_line do |line,index|
			state.line = line
			state.line_number += 1
			check_no_mix(state, line)
			case preprocessor_word(line)
				when "#if" then process_if(state, line)
				when "#ifdef" then process_ifdef(state, line)
				when "#ifndef" then process_ifndef(state, line)
				when "#elif" then process_elif(state, line)
				when "#else" then process_else(state, line)
				when "#endif" then process_end(state, line)
				else process_line(state, line)
			end
		end
		error(state, "Preprocessor directives not balanced") if state.scopes.size != 0
		
		return state.out
	end

	private
	
	Scope = Struct.new(:strip)
	State = Struct.new(:scopes, :out, :line, :line_number, :file)
	
	def error(state, s)
		raise "When processing #{state.file}:#{state.line_number}: #{state.line}\n#{s}"
	end
	
	def clean_up(line)
		line = line.sub(%r{//.*}, '')
		line = line.gsub(%r{/\*.*?\*/}, '')
		line = line.gsub(/".*?"/, '')
	end
	
	def preprocessor_word(line)
		return clean_up(line)[/^\s*(#\w+)/,1]
	end
	
	def preprocessor_data(line)
		return clean_up(line)[/^\s*(#\w+)\s+(.*)$/,2]
	end
	
	def stripping(state)
		return state.scopes.size > 0 && state.scopes[-1].strip
	end
	
	def output(state, line)
		if stripping(state)
			state.out << "//" << line.gsub(/\S/, '.')
		else
			state.out << line
		end
	end
	
	def check_no_mix(state, line)
		line = clean_up(line)
		preprocessor_word = line[/#\w+/]
		return unless preprocessor_word
		words = %(#if #ifdef #ifndef #elif #else #endif)
		return unless words.include?(preprocessor_word)
		error(state, "Mixing comments and preprocessor") if (line["/*"] || line["*/"])
		error(state, "Mixing strings and preprocessor") if line["\""]
	end
	
	
	def process_if(state, line)
		output(state, convert_tags(line))
		state.scopes << Scope.new(stripping(state) || tags_match?(state, line))
	end
	
	def process_ifdef(state, line)
		output(state, convert_tags(line))
		state.scopes << Scope.new(stripping(state) || tags_match_def?(line))
	end
	
	def process_ifndef(state, line)
		output(state, convert_tags(line))
		state.scopes << Scope.new(stripping(state))
	end
	
	def process_elif(state, line)
		error(state, "Preprocessor directives not balanced") if state.scopes.size == 0
		state.scopes.pop
		output(state, convert_tags(line))
		state.scopes << Scope.new(stripping(state) || tags_match?(state, line))
	end
	
	def process_else(state, line)
		error(state, "Preprocessor directives not balanced") if state.scopes.size == 0
		state.scopes.pop
		output(state, convert_tags(line))
		state.scopes << Scope.new(stripping(state))
	end
	
	def process_end(state, line)
		error(state, "Preprocessor directives not balanced") if state.scopes.size == 0
		state.scopes.pop
		output(state, convert_tags(line))
	end
	
	def process_line(state, line)
		output(state, line)
	end
	
	def should_strip?(state, condition)
		condition.gsub!(/defined\s*\((\w+)\)/) {|m| @tags.include?($1).to_s}
		while condition["("] do
			condition.gsub!(/\(([^)]*)\)/) {|m| should_strip?(state, $1).to_s}
		end
	
		if condition["||"]
			or_clauses = condition.split("||").collect {|x| x.strip}
			return or_clauses.all? {|clause| should_strip?(state, clause)}
		elsif condition["&&"]
			and_clauses = condition.split("&&").collect {|x| x.strip}
			return and_clauses.any? {|clause| should_strip?(state, clause)}
		elsif condition[/^!(\w+)$/]
			should_strip?(state, $1)
			return false
		elsif condition == "false"
			return false
		elsif condition == "true"
			return true
		elsif condition[/^(\w+)$/]
			return @tags.include?($1)
		elsif condition['>='] || condition['=='] || condition['>'] || condition['<'] || condition['<=']
			return false
		else
			error(state, "Condition not understood: #{condition}")
		end
	end
	
	def tags_match?(state, line)
		condition = preprocessor_data(line).strip
		# Only look at conditions that contain our tags
		return false if !(@tags.any? {|tag| condition[/\b#{tag}\b/]})
		return should_strip?(state, condition)
	end
	
	def tags_match_def?(line)
		data = preprocessor_data(line)
		return @tags.include?(data)
	end
	
	def convert_tags(line)
		@tags.each_with_index do |tag, i|
			line = line.gsub(/\b#{tag}\b/, @replace_tags[i])
		end
		return line
	end
end