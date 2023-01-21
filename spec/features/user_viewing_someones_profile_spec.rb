require "rails_helper"

# Начинаем описывать функционал, связанный с созданием игры
RSpec.feature "USER viewing someone's profile", type: :feature do
  let(:user) { FactoryGirl.create :user }
  let(:second_user) { FactoryGirl.create :user }
  let!(:questions) do
    (0..14).to_a.map do |i|
      FactoryGirl.create(
        :question, level: i,
        text: "Вопрос № #{i}?",
        answer1: "1", answer2: "2", answer3: "3", answer4: "4"
      )
    end
  end

  let(:first_game) { FactoryGirl.create(:game_with_questions, user: user) }
  let(:second_game) { FactoryGirl.create(:game_with_questions, user: user) }

  before do
    first_game.use_help(:fifty_fifty)
    first_game.current_level = 11
    first_game.take_money!

    second_game.current_level = 5
    second_game.answer_current_question!("a")

    login_as second_user
  end

  scenario "successfully" do
    visit "/"

    click_link user.name

    expect(page).to have_current_path "/users/1"

    expect(page).to have_no_content "Сменить имя и пароль"

    expect(page).to have_content "проигрыш"
    expect(page).to have_content "деньги"

    expect(page).to have_content I18n.l(first_game.created_at, format: :short)
    expect(page).to have_content I18n.l(second_game.created_at, format: :short)

    expect(page).to have_content first_game.current_level
    expect(page).to have_content second_game.current_level

    expect(page).to have_content "1 000 ₽"
    expect(page).to have_content "64 000 ₽"

    expect(page).to have_content "50/50"

  end
end
