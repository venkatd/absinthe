defmodule Absinthe.Execution.ArgumentsTest do
  use ExSpec, async: true

  import AssertResult

  defmodule Schema do
    use Absinthe.Schema

    @res %{
      true => "YES",
      false => "NO"
    }

    scalar :name do
      parse fn name -> {:ok, %{first_name: name}} end
      serialize fn %{first_name: name} -> name end
    end

    input_object :contact_input do
      field :email, :string
    end

    query do

      field :contacts, list_of(:string) do
        arg :contacts, list_of(:contact_input)

        resolve fn %{contacts: contacts}, _ ->
          {:ok, Enum.map(contacts, &Map.get(&1, :email))}
        end
      end

      field :names, list_of(:name) do
        arg :names, list_of(:name)

        resolve fn %{names: names}, _ -> {:ok, names} end
      end

      field :numbers, list_of(:integer) do
        arg :numbers, list_of(:integer)

        resolve fn %{numbers: numbers}, _ -> {:ok, numbers} end
      end

      field :user, :string do
        arg :contact, :contact_input
        resolve fn
          %{contact: %{email: email}}, _ ->
            {:ok, email}
          args, _ ->
            {:error, "Got #{inspect args} instead"}
        end
      end

      field :something,
        type: :string,
        args: [
          name: [type: :name],
          flag: [type: :boolean, default_value: false],
        ],
        resolve: fn
          %{name: %{first_name: name}}, _ ->
            {:ok, name}
          %{flag: val}, _ ->
            {:ok, @res[val]}
          _, _ ->
            {:error, "No value provided for flag argument"}
        end

      field :required_thing, :string do
        arg :name, non_null(:name)
        resolve fn
          %{name: %{first_name: name}}, _ -> {:ok, name}
          args, _ -> {:error, "Got #{inspect args} instead"}
        end
      end

    end

  end

  describe "arguments with variables" do
    describe "list inputs" do
      it "works with basic scalars" do
        doc = """
        {numbers(numbers: [1, 2])}
        """
        assert_result {:ok, %{data: %{"numbers" => [1, 2]}}}, doc |> Absinthe.run(Schema)
      end

      it "works with custom scalars" do
        doc = """
        {names(names: ["Joe", "bob"])}
        """
        assert_result {:ok, %{data: %{"names" => ["Joe", "bob"]}}}, doc |> Absinthe.run(Schema)
      end

      it "works with input objects" do
        doc = """
        {contacts(contacts: [{email: "a@b.com"}, {email: "c@d.com"}])}
        """
        assert_result {:ok, %{data: %{"contacts" => ["a@b.com", "c@d.com"]}}}, doc |> Absinthe.run(Schema)
      end
    end

    describe "input object arguments" do
      it "works in a basic case" do
        doc = """
        query FindUser($contact: ContactInput!){
          user(contact:$contact)
        }
        """
        assert_result {:ok, %{data: %{"user" => "bubba@joe.com"}}}, doc |> Absinthe.run(Schema, variables: %{"contact" => %{"email" => "bubba@joe.com"}})
      end
    end

    describe "custom scalar arguments" do
      it "works when specified as non null" do
        doc = """
        { requiredThing(name: "bob") }
        """
        assert_result {:ok, %{data: %{"requiredThing" => "bob"}}}, doc |> Absinthe.run(Schema)
      end
      it "works when passed to resolution" do
        assert_result {:ok, %{data: %{"something" => "bob"}}}, "{ something(name: \"bob\") }" |> Absinthe.run(Schema)
      end
    end

    describe "boolean arguments" do

      it "are passed as arguments to resolution functions correctly" do
        doc = """
        query DoSomething($flag: Boolean!) {
          something(flag:$flag)
        }
        """
        assert_result {:ok, %{data: %{"something" => "YES"}}}, doc |> Absinthe.run(Schema, variables: %{"flag" => true})
        assert_result {:ok, %{data: %{"something" => "NO"}}}, doc |> Absinthe.run(Schema, variables: %{"flag" => false})
      end

    end
  end

  describe "literal arguments" do
    describe "missing arguments" do
      it "returns the appropriate error" do
        doc = """
        { requiredThing }
        """
        assert_result {:ok, %{data: %{}, errors: [%{message: "Field `requiredThing': Got %{} instead"}]}}, doc |> Absinthe.run(Schema)
      end
    end

    describe "list inputs" do
      it "works with basic scalars" do
        doc = """
        {numbers(numbers: [1, 2])}
        """
        assert_result {:ok, %{data: %{"numbers" => [1, 2]}}}, doc |> Absinthe.run(Schema)
      end

      it "works with custom scalars" do
        doc = """
        {names(names: ["Joe", "bob"])}
        """
        assert_result {:ok, %{data: %{"names" => ["Joe", "bob"]}}}, doc |> Absinthe.run(Schema)
      end

      it "works with input objects" do
        doc = """
        {contacts(contacts: [{email: "a@b.com"}, {email: "c@d.com"}])}
        """
        assert_result {:ok, %{data: %{"contacts" => ["a@b.com", "c@d.com"]}}}, doc |> Absinthe.run(Schema)
      end
    end

    describe "input object arguments" do
      it "works in a basic case" do
        doc = """
        {user(contact: {email: "bubba@joe.com"})}
        """
        assert_result {:ok, %{data: %{"user" => "bubba@joe.com"}}}, doc |> Absinthe.run(Schema)
      end
    end

    describe "custom scalar arguments" do
      it "works when specified as non null" do
        doc = """
        { requiredThing(name: "bob") }
        """
        assert_result {:ok, %{data: %{"requiredThing" => "bob"}}}, doc |> Absinthe.run(Schema)
      end
      it "works when passed to resolution" do
        assert_result {:ok, %{data: %{"something" => "bob"}}}, "{ something(name: \"bob\") }" |> Absinthe.run(Schema)
      end
    end

    describe "boolean arguments" do

      it "are passed as arguments to resolution functions correctly" do
        assert_result {:ok, %{data: %{"something" => "YES"}}}, "{ something(flag: true) }" |> Absinthe.run(Schema)
        assert_result {:ok, %{data: %{"something" => "NO"}}}, "{ something(flag: false) }" |> Absinthe.run(Schema)
        assert_result {:ok, %{data: %{"something" => "NO"}}}, "{ something }" |> Absinthe.run(Schema)
      end

    end
  end

end
