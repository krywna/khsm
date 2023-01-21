# (c) goodprogrammer.ru

# Стандартный rspec-овский помощник для rails-проекта
require 'rails_helper'

# Наш собственный класс с вспомогательными методами
require 'support/my_spec_helper'

# Тестовый сценарий для модели Игры
#
# В идеале — все методы должны быть покрыты тестами, в этом классе содержится
# ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # Пользователь для создания игр
  let(:user) { FactoryBot.create(:user) }

  # Игра с прописанными игровыми вопросами
  let(:game_w_questions) do
    FactoryBot.create(:game_with_questions, user: user)
  end

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # Генерим 60 вопросов с 4х запасом по полю level, чтобы проверить работу
      # RANDOM при создании игры.
      generate_questions(60)

      game = nil

      # Создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
        # Проверка: Game.count изменился на 1 (создали в базе 1 игру)
      }.to change(Game, :count).by(1).and(
        # GameQuestion.count +15
        change(GameQuestion, :count).by(15).and(
          # Game.count не должен измениться
          change(Question, :count).by(0)
        )
      )

      # Проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)

      # Проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  # Тесты на основную игровую логику
  context 'game mechanics' do

    describe "#current_game_question" do
      it "return current question" do
        expect(game_w_questions.current_game_question).to eq game_w_questions.game_questions[0]
      end
    end

    describe "#previous_level" do
      before do
        q = game_w_questions.current_game_question
        game_w_questions.answer_current_question!(q.correct_answer_key)
      end

      it "return previous_level" do
        expect(game_w_questions.previous_level).to eq 0
      end
    end

    # Правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # Текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # Перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)

      # Ранее текущий вопрос стал предыдущим
      expect(game_w_questions.current_game_question).not_to eq(q)

      # Игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be false
    end
  end

  describe "#answer_current_question!" do
    before do
      game_w_questions.current_level = level
      game_w_questions.created_at = start_time
      game_w_questions.answer_current_question!(answer_key)
    end
    let!(:level) { game_w_questions.current_level }
    let!(:start_time) { Time.now }

    context "answer correct" do
      let!(:answer_key) { game_w_questions.current_game_question.correct_answer_key }

      context "last question" do
        let!(:level) { Question::QUESTION_LEVELS.max }

        it "assigns final prize" do
          expect(game_w_questions.prize).to eq Game::PRIZES.last
        end

        it "win game" do
          expect(game_w_questions.status).to eq(:won)
        end
      end

      context "not last question" do
        it "moves to next level" do
          expect(game_w_questions.current_level).to eq 1
        end

        it "continues game" do
          expect(game_w_questions.status).to eq(:in_progress)
        end
      end

      context "timeout" do
        let!(:start_time) { 1.hour.ago }

        it "finishes game with status timeout" do
          expect(game_w_questions.status).to eq(:timeout)
        end
      end
    end

    context "wrong answer" do
      let!(:answer_key) { "a" }

      it "finish game" do
        expect(game_w_questions.finished?).to be true
      end

      it "finishes with status fail" do
        expect(game_w_questions.status).to eq(:fail)
      end
    end
  end
end
