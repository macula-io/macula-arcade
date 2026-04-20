defmodule MaculaArcade.SnakeMaster.Player do
  @moduledoc """
  A SnakeMaster - the player who owns and trains snakes.

  Players earn coins through battles and reputation through victories.
  Supports local authentication with username/password.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias MaculaArcade.SnakeMaster.Snake

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # ISO 3166-1 alpha-2 country codes for flag display
  @country_codes ~w(
    AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ
    CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR
    GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP
    KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ
    NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW
    SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ
    UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW
  )

  schema "players" do
    field :name, :string
    field :coins, :integer, default: 100
    field :reputation, :integer, default: 0
    field :peer_id, :string

    # Authentication fields
    field :password_hash, :string
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true

    # Optional email for recovery
    field :email, :string

    # Profile display fields
    field :avatar_url, :string
    field :location, :string
    field :country_code, :string

    has_many :snakes, Snake

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name]
  @optional_fields [:coins, :reputation, :peer_id, :email, :avatar_url, :location, :country_code]

  def changeset(player, attrs) do
    player
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 2, max: 50)
    |> validate_number(:coins, greater_than_or_equal_to: 0)
    |> validate_number(:reputation, greater_than_or_equal_to: 0)
    |> validate_format(:email, ~r/@/, message: "must be a valid email")
    |> validate_inclusion(:country_code, @country_codes, message: "must be a valid country code")
    |> unique_constraint(:name)
    |> unique_constraint(:email)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end

  @doc """
  Changeset for registration with password.
  """
  def registration_changeset(player, attrs) do
    player
    |> changeset(attrs)
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 100)
    |> validate_confirmation(:password)
    |> hash_password()
  end

  @doc """
  Changeset for updating profile (without password).
  """
  def profile_changeset(player, attrs) do
    player
    |> cast(attrs, [:email, :avatar_url, :location, :country_code])
    |> validate_format(:email, ~r/@/, message: "must be a valid email")
    |> validate_inclusion(:country_code, @country_codes, message: "must be a valid country code")
    |> unique_constraint(:email)
  end

  @doc """
  Changeset for changing password.
  """
  def password_changeset(player, attrs) do
    player
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 100)
    |> validate_confirmation(:password)
    |> hash_password()
  end

  @doc """
  Verifies a password against the stored hash.
  """
  def verify_password(%__MODULE__{password_hash: nil}, _password), do: false

  def verify_password(%__MODULE__{password_hash: hash}, password) do
    Bcrypt.verify_pass(password, hash)
  end

  @doc """
  Returns the country flag emoji for a country code.
  """
  def country_flag(nil), do: ""

  def country_flag(code) when is_binary(code) do
    code
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.map(&(&1 + 127_397))
    |> List.to_string()
  end

  # Private helpers

  defp hash_password(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp hash_password(changeset), do: changeset
end
