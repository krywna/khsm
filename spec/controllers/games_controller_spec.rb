# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryGirl.create(:user) }
  # админ
  let(:admin) { FactoryGirl.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  describe "#create" do
    context 'Anon' do
      # из экшена show анона посылаем
      it 'kick from #show' do
        # вызываем экшен
        get :show, id: game_w_questions.id
        # проверяем ответ
        expect(response.status).not_to eq(200) # статус не 200 ОК
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end
    end

    # группа тестов на экшены контроллера, доступных залогиненным юзерам
    context 'Usual user' do
      # перед каждым тестом в группе
      before(:each) { sign_in user }

      # юзер может создать новую игру
      it 'creates game' do
        # сперва накидаем вопросов, из чего собирать новую игру
        generate_questions(15)

        post :create
        game = assigns(:game) # вытаскиваем из контроллера поле @game

        # проверяем состояние этой игры
        expect(game.finished?).to be false
        expect(game.user).to eq(user)
        # и редирект на страницу этой игры
        expect(response).to redirect_to(game_path(game))
        expect(flash[:notice]).to be
      end

      it "can't create second game" do
        sign_in user
        generate_questions(15)
        post :create
        game = assigns(:game)
        request.env["HTTP_REFERER"] = game_url(game)

        generate_questions(15)
        expect { post :create }.to change(Game, :count).by(0)

        expect(response).to redirect_to :back
        expect(flash[:alert]).to be
      end
    end
  end

  describe "#show" do
    context "anon" do
      # из экшена show анона посылаем
      before { get :show, id: game_w_questions.id }

      it "return not OK status" do
        expect(response.status).not_to eq(200) # статус не 200 ОК
      end

      it "redirect right" do
        expect(response).to redirect_to(new_user_session_path)
      end

      it "kick from #show" do
        expect(flash[:alert]).not_to be_empty # во flash должен быть прописана ошибка
      end
    end

    context "usual user" do
      let(:second_user) { FactoryGirl.create(:user) }
      # игра с прописанными игровыми вопросами
      let(:second_game_w_questions) { FactoryGirl.create(:game_with_questions, user: second_user) }

      # перед каждым тестом в группе
      before { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in

      # юзер видит свою игру

      it '#show game' do
        get :show, id: game_w_questions.id
        game = assigns(:game) # вытаскиваем из контроллера поле @game
        expect(game.finished?).to be_falsey
        expect(game.user).to eq(user)

        expect(response.status).to eq(200) # должен быть ответ HTTP 200
        expect(response).to render_template('show') # и отрендерить шаблон show
      end

      # юзер не видит чужую игру
      it "don't show game" do
        get :show, id: second_game_w_questions.id
        game = assigns(:game) # вытаскиваем из контроллера поле @game

        expect(response.status).to eq(302) # должен быть ответ HTTP 302
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).not_to be_empty
      end
    end
  end

  describe "#answer" do
    context "anon" do
        # вызываем экшен
        before { put :answer, id: game_w_questions.id }

        # проверяем ответ
        it "not 200 status" do
          expect(response.status).not_to eq(200) # статус не 200 ОК
        end

        it "redirect to login form" do
          expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        end

        it "alert not empty" do
          expect(flash[:alert]).not_to be_empty # во flash должен быть прописана ошибка
        end
    end

    context "usual user" do
      # перед каждым тестом в группе
      before do
        sign_in user # логиним юзера user с помощью спец. Devise метода sign_in
        put :answer, id: game_w_questions.id, letter: letter
      end

      let!(:game) { assigns(:game) }

      context "correct answer" do
        let!(:letter) { game_w_questions.current_game_question.correct_answer_key }
        # юзер отвечает на игру корректно - игра продолжается
        it "doesn't finish game" do
          expect(game.finished?).to be false
        end

        it "move on next level" do
          expect(game.current_level).to be > 0
        end

        it "redirect to current game" do
          expect(response).to redirect_to(game_path(game))
        end

        it "doesn't flash" do
          expect(flash).to be_empty # удачный ответ не заполняет flash
        end
      end

      context "wrong answer" do
        let!(:letter) { "a" }

        it "finish game" do
          expect(game.finished?).to be true
        end

        it "game status 'fail'" do
          expect(game.status).to eq(:fail)
        end

        it "doesn't move on next level" do
          expect(game.current_level).to eq 0
        end

        it "redirect to user page" do
          expect(response).to redirect_to(user_path(user))
        end

        it "flashes" do
          expect(flash[:alert]).not_to be_empty
        end
      end
    end
  end

  describe "#take_money" do
    context "anon" do
      it "kick from #take_money" do
        # вызываем экшен
        put :take_money, id: game_w_questions.id
        # проверяем ответ
        expect(response.status).not_to eq(200) # статус не 200 ОК
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        expect(flash[:alert]).not_to be_empty # во flash должен быть прописана ошибка
      end
    end

    context "usual user" do
      let(:second_user) { FactoryGirl.create(:user) }
      # игра с прописанными игровыми вопросами
      let(:second_game_w_questions) { FactoryGirl.create(:game_with_questions, user: second_user) }

      # перед каждым тестом в группе
      before { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in
        it "take money" do
        game_w_questions.update_attribute(:current_level, 2)

        put :take_money, id: game_w_questions.id
        game = assigns(:game)

        expect(game.finished?).to be true
        expect(game.prize).to eq(200)

        user.reload
        expect(user.balance).to eq(200)

        expect(response).to redirect_to(user_path(game.user))
        expect(flash[:warning]).not_to be_empty
      end
    end
  end

  describe "#help" do
    before { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in

    context "audience help" do
      # перед каждым тестом в группе
    # тест на отработку "помощи зала"
      it 'uses audience help' do
        # сперва проверяем что в подсказках текущего вопроса пусто
        expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
        expect(game_w_questions.audience_help_used).to be false

        # фигачим запрос в контроллен с нужным типом
        put :help, id: game_w_questions.id, help_type: :audience_help
        game = assigns(:game)

        # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
        expect(game.finished?).to be_falsey
        expect(game.audience_help_used).to be_truthy
        expect(game.current_game_question.help_hash[:audience_help]).to be
        expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
        expect(response).to redirect_to(game_path(game))
      end
    end
  end
end
