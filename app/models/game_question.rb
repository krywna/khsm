require 'game_help_generator'
class GameQuestion < ActiveRecord::Base
  belongs_to :game

  belongs_to :question

  delegate :text, :level, to: :question, allow_nil: true

  validates :game, :question, presence: true

  validates :a, :b, :c, :d, inclusion: {in: 1..4}

  serialize :help_hash, Hash

  # help_hash у нас имеет такой формат:
  # {
  #   # При использовании подсказски остались варианты a и b
  #   fifty_fifty: ['a', 'b'],
  #
  #   # Распределение голосов по вариантам a, b, c, d
  #   audience_help: {'a' => 42, 'c' => 37 ...},
  #
  #   # Друг решил, что правильный ответ А (просто пишем текстом)
  #   friend_call: 'Василий Петрович считает, что правильный ответ A'
  # }
  def variants
    {
      'a' => question.read_attribute("answer#{a}"),
      'b' => question.read_attribute("answer#{b}"),
      'c' => question.read_attribute("answer#{c}"),
      'd' => question.read_attribute("answer#{d}")
    }
  end

  def answer_correct?(letter)
    correct_answer_key == letter.to_s.downcase
  end

  def correct_answer_key
    {a => 'a', b => 'b', c => 'c', d => 'd'}[1]
  end

  def correct_answer
    variants[correct_answer_key]
  end

  def add_fifty_fifty
    self.help_hash[:fifty_fifty] = [
      correct_answer_key,
      (%w(a b c d) - [correct_answer_key]).sample
    ]

    save
  end

  def add_audience_help
    # Массив ключей
    keys_to_use = keys_to_use_in_help

    self.help_hash[:audience_help] =
      GameHelpGenerator.audience_distribution(keys_to_use, correct_answer_key)

    save
  end

  def add_friend_call
    keys_to_use = keys_to_use_in_help

    self.help_hash[:friend_call] =
      GameHelpGenerator.friend_call(keys_to_use, correct_answer_key)

    save
  end

  private

  def keys_to_use_in_help
    keys_to_use = variants.keys

    keys_to_use = help_hash[:fifty_fifty] if help_hash.has_key?(:fifty_fifty)

    keys_to_use
  end
end
