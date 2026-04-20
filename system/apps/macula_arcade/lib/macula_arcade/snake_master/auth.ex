defmodule MaculaArcade.SnakeMaster.Auth do
  @moduledoc """
  Authentication context for player login/registration.

  Provides functions to register new players, authenticate existing players,
  and manage sessions. Uses bcrypt for password hashing.
  """

  import Ecto.Query
  alias MaculaArcade.Repo
  alias MaculaArcade.SnakeMaster.Player

  @doc """
  Registers a new player with username and password.

  ## Examples

      iex> register_player(%{name: "snake_master", password: "secret123", password_confirmation: "secret123"})
      {:ok, %Player{}}

      iex> register_player(%{name: "x", password: "short"})
      {:error, %Ecto.Changeset{}}
  """
  def register_player(attrs) do
    %Player{}
    |> Player.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Authenticates a player by username and password.

  Returns {:ok, player} if credentials are valid, {:error, :invalid_credentials} otherwise.
  """
  def authenticate(username, password) when is_binary(username) and is_binary(password) do
    player = get_player_by_name(username)

    case player do
      nil ->
        # Perform dummy check to prevent timing attacks
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      player ->
        if Player.verify_password(player, password) do
          {:ok, player}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  def authenticate(_, _), do: {:error, :invalid_credentials}

  @doc """
  Gets a player by their ID.
  """
  def get_player(id) when is_binary(id) do
    Repo.get(Player, id)
  end

  def get_player(_), do: nil

  @doc """
  Gets a player by their username (name field).
  """
  def get_player_by_name(name) when is_binary(name) do
    Repo.get_by(Player, name: name)
  end

  def get_player_by_name(_), do: nil

  @doc """
  Gets a player by their email address.
  """
  def get_player_by_email(email) when is_binary(email) do
    Repo.get_by(Player, email: email)
  end

  def get_player_by_email(_), do: nil

  @doc """
  Updates a player's profile (non-password fields).
  """
  def update_profile(player, attrs) do
    player
    |> Player.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a player's password.
  """
  def update_password(player, attrs) do
    player
    |> Player.password_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists all players, optionally limited.
  """
  def list_players(limit \\ 100) do
    Player
    |> limit(^limit)
    |> order_by([p], desc: p.reputation)
    |> Repo.all()
  end

  @doc """
  Checks if a username is available.
  """
  def username_available?(name) when is_binary(name) do
    is_nil(get_player_by_name(name))
  end

  def username_available?(_), do: false

  @doc """
  Checks if an email is available.
  """
  def email_available?(nil), do: true
  def email_available?(""), do: true

  def email_available?(email) when is_binary(email) do
    is_nil(get_player_by_email(email))
  end

  def email_available?(_), do: false

  @doc """
  Gets or creates a player by name.
  For backwards compatibility with the auto-generated player names.
  If player doesn't exist, creates one without a password (guest mode).
  """
  def get_or_create_player(name) when is_binary(name) do
    case get_player_by_name(name) do
      nil ->
        # Create guest player (no password)
        %Player{}
        |> Player.changeset(%{name: name})
        |> Repo.insert()

      player ->
        {:ok, player}
    end
  end

  def get_or_create_player(_), do: {:error, :invalid_name}

  @doc """
  Checks if a player has set a password (is registered vs guest).
  """
  def has_password?(%Player{password_hash: nil}), do: false
  def has_password?(%Player{password_hash: _}), do: true
  def has_password?(_), do: false

  @doc """
  Converts a guest player to a registered player by adding a password.
  """
  def set_password(%Player{password_hash: nil} = player, password, password_confirmation) do
    player
    |> Player.password_changeset(%{
      password: password,
      password_confirmation: password_confirmation
    })
    |> Repo.update()
  end

  def set_password(%Player{}, _, _), do: {:error, :already_has_password}
  def set_password(_, _, _), do: {:error, :invalid_player}
end
