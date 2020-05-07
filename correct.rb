#!/usr/bin/env ruby

## An AutoCorrect implementation
class AutoCorrect
  attr_accessor :dictionary

  # Load a list of known words an their word count from a given file.
  # See: https://en.wiktionary.org/wiki/Wiktionary:Frequency_lists/PG/2006/04/1-10000
  # Expected format:
  #   rank    word            instances (per billion) in corpus
  #   ....
  #   2784    notwithstanding 27812.3
  #   2785    shock           27777.5
  #   2786    exception       27775.9
  #   ....
  #
  def initialize(wordfile)
    @dictionary = {}
    File.open(wordfile).each do |line|
      _rank, word, count = line.split
      @dictionary[word] = count.to_i
    end
  end

  # Given a word, determine the top 10 corrections
  def corrections(word)
    candidates(word).max_by(10) do |candidate|
      probability(candidate)
    end
  end

  # Determine the total number of words from the corpus
  def total_count
    @total_count ||= dictionary.values.inject(0.0, :+)
  end

  # the probability of a word in the overall list
  def probability(word)
    (dictionary[word] || 0) / total_count
  end

  def debug(msg)
    STDERR << "\033[31m" + msg + "\033[0m\n" if ENV['DEBUG']
  end

  private

  # Determine the best candidates corrections for a given word
  # 1. The word is already known
  # 2. Any single character changes to the word
  # 3. Any double character changes to the word
  # 4. Return the 'word'
  def candidates(word)
    return [word] if dictionary[word]

    found = known(edits(word))
    return found if found.any?

    found = known(double_edits(word))
    return found if found.any?

    [word]
  end

  # Given a list of mutations, pick the ones which are known words
  def known(mutated)
    debug("Checking #{mutated.count} mutations.")
    mutated.select do |word|
      dictionary[word]
    end
  end

  # splits up the word at character boundaries
  # `fo` is ['', 'fo'], ['f', 'o'], ['fo', '']
  def split_word(word)
    (word.length + 1).times.map do |time|
      [word[0, time], word[time..]]
    end
  end

  # delete a character at the boundary
  # `fo` is ['f', 'o']
  def deletions(splits)
    splits.map do |first, second|
      [first, second[1..]].join
    end
  end

  # transpose two characters at the boundary
  # `ofo` is ['foo', 'oof']
  def transpositions(splits)
    splits.map do |first, second|
      [first, second[1], second[0], second[2..]].join if second.length > 1
    end
  end

  # replace letters at the boundary using our character set
  # `foo` would include ['aoo', 'boo', 'fao', 'fbo', ...]
  def replacements(splits)
    splits.map do |first, second|
      letters.map { |l| [first, l, second[1..]].join }
    end
  end

  # insert letters at the boundary using our character set
  # `foo` would include ['afoo', 'fboo', 'foco', ...]
  def insertions(splits)
    splits.map do |first, second|
      letters.map { |l| [first, l, second].join }
    end
  end

  # the characters in our character set
  def letters
    @letters ||= 'abcdefghijklmnopqrstuvwxyz'.chars
  end

  # Perform edits to a given word and collect them for suggestions
  def edits(word)
    splits = split_word(word)

    mutated = deletions(splits)
    mutated << transpositions(splits)
    mutated << replacements(splits)
    mutated << insertions(splits)

    mutated.flatten.uniq.compact
  end

  # perform edits to a word....TWICE
  # this will account for cases where the user fat fingers more than one letter.
  def double_edits(word)
    mutated = edits(word)
    [mutated, mutated.map { |w| edits(w) }].flatten.uniq
  end
end

word = ARGV.shift
a = AutoCorrect.new 'big.txt'
puts "Corrections for #{word}"

a.corrections(word).each_with_index do |correction, index|
  puts "  #{index}. #{correction}"
  a.debug("  Probability: #{a.probability(correction)}")
end
