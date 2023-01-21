require "rails_helper"

# Тест на шаблон users/show.html.erb

RSpec.describe "users/show", type: :view do
  let(:user) { create(:user) }

  context "user on his page" do
    before do
      sign_in user

      assign(:user, user)
      assign(:games, [stub_template("users/_game.html.erb" => "User games render here")])

      render
    end

    # Проверяем, что шаблон выводит имя юзера
    it "renders user name" do
      expect(rendered).to match user.name
    end

    # Проверяем, что шаблон выводит ссылку на смену пароля
    it "renders change password link" do
      expect(rendered).to match "Сменить имя и пароль"
    end

    it "render game partial" do
      expect(rendered).to match "User games render here"
    end
  end

  context "user on someone's page" do
    let(:second_user) { create(:user) }

    before do
      sign_in second_user
      assign(:user, user)

      render
    end

    # Проверяем, что шаблон выводит имя юзера
    it "renders user name" do
      expect(rendered).to match user.name
    end

    # Проверяем, что шаблон не выводит ссылку на смену пароля
    it "renders change password link" do
      expect(rendered).not_to match "Сменить имя и пароль"
    end
  end
end
