# This class represents an entry in the look-up table used to reverse translate
# a given log message. Here, we take as input a parsed-out POT file entry 
# (generated by POParser) and from there, we convert message strings of the form
# p1 m1 p2 m2 ... where p1 = parameter 1, m1 = message 1 to regexes of the form
# (.*) m1 (.*) m2 ... and map these regexes to the corresponding msgid (or msgid_plural).
#
# TODO: Make it more OOP later! (not right now)
class POEntry
  # TODO: Maybe refactor these? Bit hard to read
  PARAM_SUB_RE = /(?:\A|([^\\]))\\\{\d+\\\}/
  PARAM_RE = /(?:\A|([^\\]))\{\d+\}/

  #TODO: Remove accesses to these attributes after testing!
  attr_reader :translations 

  def initialize(pot_entry)
    msgid_part, msgstr_part = pot_entry
    # TODO: Check ruby version. If > 2.1, then can use map w/o the to_a
    @translations = msgstr_part.to_a.map do |key, value| 
      key_regex = to_regex(value)
      translation = msgid_part["msgid#{"_plural" if key !~ /\Amsgstr(\[0\])?\Z/}"]
      [key_regex, translation]
    end.to_h
  end
  
  def to_regex(msgstr) 
    Regexp.new(Regexp.escape(msgstr).gsub(PARAM_SUB_RE,'\1(?m-ix:(.*))'))
  end

  # This method does the reverse translation. Here we find the first matching
  # msgstr in our translation map, extract out the parameters, translate it to
  # its original form, and then put the parameters back in. Note that only part
  # of the message might be translated.
  def reverse_translate(msg)
    match_re = @translations.keys.find { |k| msg =~ k }
    return msg if match_re == nil 
    match_obj = match_re.match(msg) 
    translated_part = match_obj[1..-1].inject(@translations[match_re]) do |new_msg, param|
      new_msg.sub(PARAM_RE, "\\1#{param}")
    end
    match_obj.pre_match + translated_part + match_obj.post_match
  end
end