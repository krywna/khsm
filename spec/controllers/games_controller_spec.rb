# (c) goodprogrammer.ru

require "rails_helper"
require "support/my_spec_helper" # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryBot.create(:user) }
  # админ
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  describe "#create" do
    context "Anon" do
      # из экшена show анона посылаем
      before { get :show, id: game_w_questions.id }

      it "return not 200" do
        expect(response.status).not_to eq(200) # статус не 200 ОК
      end

      it "kick from #show" do
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
      end

      it "show alert" do
        expect(flash[:alert]).to be # во flash должен быть прописана ошибка
      end
    end

    # группа тестов на экшены контроллера, доступных залогиненным юзерам
    context "Usual user" do
      # перед каждым тестом в группе
      context "the first game" do
        before do
          sign_in user
          # сперва накидаем вопросов, из чего собирать новую игру
          generate_questions(15)
          # юзер может создать новую игру
          post :create
        end

        let(:game) { game = assigns(:game) } # вытаскиваем из контроллера поле @game

        it "new game isn't finished" do
          # проверяем состояние этой игры
          expect(game.finished?).to be false
        end

        it "right owner" do
          expect(game.user).to eq(user)
        end

        it "redirect on game page" do
          #редирект на страницу этой игры
          expect(response).to redirect_to(game_path(game))
        end

        it "add flash" do
          expect(flash[:notice]).to be
        end
      end

      context "try to create the second game" do
        before do
          sign_in user
          generate_questions(15)
          post :create
          game = assigns(:game)
          request.env["HTTP_REFERER"] = game_url(game)
          generate_questions(15)
        end

        it "can't create second game" do
          expect { post :create }.to change(Game, :count).by(0)
        end

        it "redirect back" do
          expect(response).to redirect_to :back
        end

        before { post :create }

        it "add flash" do
          expect(flash[:alert]).to be
        end
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
      let(:second_user) { FactoryBot.create(:user) }
      # игра с прописанными игровыми вопросами
      let(:second_game_w_questions) { FactoryBot.create(:game_with_questions, user: second_user) }

      # перед каждым тестом в группе
      before do
        # логиним юзера user с помощью спец. Devise метода sign_in
        sign_in user
        get :show, id: game_w_questions.id
      end

      let(:game) { game = assigns(:game) } # вытаскиваем из контроллера поле @game

      # юзер видит свою игру
      context "owner see his game" do
        it "game isn't finished" do
          expect(game.finished?).to be false
        end

        it "right user owner" do
          expect(game.user).to eq(user)
        end

        it "status OK" do
          expect(response.status).to eq(200) # должен быть ответ HTTP 200
        end

        it "render show" do
          expect(response).to render_template("show") # и отрендерить шаблон show
        end
      end

      # юзер не видит чужую игру
      context "user can't see someone's game" do
        before do
          get :show, id: second_game_w_questions.id
        end

        let(:game) { game = assigns(:game) } # вытаскиваем из контроллера поле @game

        it "status Found" do
          expect(response.status).to eq(302) # должен быть ответ HTTP 302
        end

        it "redirect to home page" do
          expect(response).to redirect_to(root_path)
        end

        it "add flash" do
          expect(flash[:alert]).not_to be_empty
        end
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
      before { put :take_money, id: game_w_questions.id } # вызываем экшен

      it "status not Ok" do
        expect(response.status).not_to eq(200) # статус не 200 ОК
      end

      it "redirect to registration" do
        expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
      end

      it "add flash" do
        expect(flash[:alert]).not_to be_empty # во flash должен быть прописана ошибка
      end
    end

    context "usual user" do
      # перед каждым тестом в группе
      before do
        sign_in user
        game_w_questions.update_attribute(:current_level, 2)
        put :take_money, id: game_w_questions.id
      end

      let(:game) { assigns(:game) }

      it "game is finished" do
        expect(game.finished?).to be true
      end

      it "status Ok" do
        expect(game.prize).to eq(200)
      end

      before { user.reload }

      it "right balance" do
        expect(user.balance).to eq(200)
      end

      it "redirect to user page" do
        expect(response).to redirect_to(user_path(game.user))
      end

      it "add flash" do
        expect(flash[:warning]).not_to be_empty
      end
    end
  end

  describe "#help" do
    before { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in

    context "audience help" do
    # тест на отработку "помощи зала"

      it "audience help isn't used" do
        expect(game_w_questions.audience_help_used).to be false
      end

      let(:game) { assigns(:game) }
      before { put :help, id: game_w_questions.id, help_type: :audience_help }

      it "continue game" do
        # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
        expect(game.finished?).to be false
      end

      it "audience help is used" do
        expect(game.audience_help_used).to be true
      end

      it "add to help hash" do
        expect(game.current_game_question.help_hash[:audience_help]).to be
      end

      it "right variants" do
        expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly("a", "b", "c", "d")
      end

      it "redirect to game" do
        expect(response).to redirect_to(game_path(game))
      end
    end

    context "fifty fifty used" do
      before { put :help, id: game_w_questions.id, help_type: :fifty_fifty }
      let!(:game) { assigns(:game) }

      it "game isn't finished" do
        expect(game.finished?).to be false
      end

      it "used" do
        expect(game.fifty_fifty_used).to be true
      end

      it "include in help_hash" do
        expect(game.current_game_question.help_hash[:fifty_fifty]).to be
      end

      it "include rigth answer" do
        expect(game.current_game_question.help_hash[:fifty_fifty].first).to eq("d")
      end

      it "include one wrong answer" do
        expect(%w[a b c]).to include(game.current_game_question.help_hash[:fifty_fifty].last)
      end

      it "correct redirect" do
        expect(response).to redirect_to(game_path(game))
      end
    end

    context "fifty fifty didn't used" do
      it "help hash doesn't include" do
        expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
      end

      it "didn't use" do
        expect(game_w_questions.fifty_fifty_used).to be false
      end
    end
  end
end
