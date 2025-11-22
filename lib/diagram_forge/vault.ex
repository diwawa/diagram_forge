defmodule DiagramForge.Vault do
  @moduledoc """
  Vault for encrypting sensitive data at rest.

  Used for encrypting OAuth provider tokens and other sensitive fields.
  """

  use Cloak.Vault, otp_app: :diagram_forge

  defmodule EncryptedBinary do
    @moduledoc """
    Ecto type for encrypted binary fields.
    """
    use Cloak.Ecto.Binary, vault: DiagramForge.Vault
  end
end
