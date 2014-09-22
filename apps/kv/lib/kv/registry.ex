defmodule KV.Registry do
  use GenServer
  ##客户端API

  @doc """
  启动注册表进程
  """
  def start_link(table, event_manager, buckets, opts \\ []) do
    GenServer.start_link(__MODULE__, {table, event_manager, buckets}, opts)
  end

  @doc """
  根据名称查找存储在`服务器`端的“桶”的进程号(pid)
  如果“桶”存在，返回 `{:ok,pid}`，否则返回`:error`。
  """
  def lookup(table,name) do
    case :ets.lookup(table, name) do
      [{^name, bucket}] -> {:ok, bucket}
      [] -> :error
    end
  end

  @doc """
  保证服务器端`server`存在一个指定名称`name`相关联的“桶”
  """
  def create(server, name) do
    GenServer.call(server, {:create, name})
  end

  @doc """
  停止注册表进程
  """
  def stop(server) do
    GenServer.call(server, :stop)
  end

  ##服务器端回调
  def init({table,events,buckets}) do
    refs = :ets.foldl(fn {name, pid}, acc ->
      HashDict.put(acc, Process.monitor(pid), name)
    end, HashDict.new, table)

    {:ok, %{names: table, refs: refs, events: events, buckets: buckets}}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call({:create, name}, _from, state) do
    case lookup(state.names, name) do
      {:ok, pid} ->
        {:reply, pid, state}
      :error ->
        {:ok,pid} = KV.Bucket.Supervisor.start_bucket(state.buckets)
        ref = Process.monitor(pid)
        refs = HashDict.put(state.refs, ref, name)
        :ets.insert(state.names, {name, pid})
        GenEvent.sync_notify(state.events, {:create, name, pid})
        {:reply, pid, %{state| refs: refs}}
    end
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    {name, refs} = HashDict.pop(state.refs, ref)
    :ets.delete(state.names, name)
    GenEvent.sync_notify(state.events, {:exit, name, pid})
    {:noreply, %{state| refs: refs}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end