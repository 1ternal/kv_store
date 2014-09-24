defmodule KVServerTest do
  use ExUnit.Case

  setup do
    Logger.remove_backend(:console)
    Application.stop(:kv)
    :ok = Application.start(:kv)
    Logger.add_backend(:console, flush: true)
    :ok
  end

  setup do
    opts = [:binary, packet: :line, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 4040, opts)
    {:ok, socket: socket}
  end

  test "server interaction", %{socket: socket} do
    assert send_and_recv(socket, "UNKNOWN shopping\r\n") == "UNKNOWN COMMAND\r\n"

    assert send_and_recv(socket, "GET shopping eggs\r\n") == "NOT FOUND\r\n"

    assert send_and_recv(socket, "CREATE shopping\r\n") == "OK\r\n"

    assert send_and_recv(socket, "PUT shopping eggs 3\r\n") == "OK\r\n"

    #GET返回两行
    assert send_and_recv(socket, "GET shopping eggs\r\n") ==  "3\r\n"
    assert send_and_recv(socket, "") == "OK\r\n"

    assert send_and_recv(socket, "DELETE shopping eggs\r\n") == "OK\r\n"
  end

  defp send_and_recv(socket, command) do
    :ok = :gen_tcp.send(socket, command)
    {:ok, data} = :gen_tcp.recv(socket, 0, 1000)
    data
  end
end