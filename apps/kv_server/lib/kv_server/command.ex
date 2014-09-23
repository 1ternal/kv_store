defmodule KVServer.Command do
  @doc ~S"""
  将给定的`行`解析成命令。

  ##Examples
    iex> KVServer.Command.parse "CREATE shopping\r\n"
    {:ok, {:create, "shopping"}}

  """

  def parse(line) do
    :not_implemented
  end

end