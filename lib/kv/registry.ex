defmodule KV.Registry do
  use GenServer
  ##客户端API

  @doc """
  启动注册表进程
  """
  def start_link(event_manager, opts \\ []) do
    #1.start_link现在期望收到一个事件管理器作为参数
    GenServer.start_link(__MODULE__, event_manager, opts)
  end

  @doc """
  根据名称查找存储在`服务器`端的“桶”的进程号(pid)
  如果“桶”存在，返回 `{:ok,pid}`，否则返回`:error`。
  """
  def lookup(server,name) do
    GenServer.call(server, {:lookup, name})
  end

  @doc """
  保证服务器端`server`存在一个指定名称`name`相关联的“桶”
  """
  def create(server, name) do
    GenServer.cast(server, {:create, name})
  end

  @doc """
  停止注册表进程
  """
  def stop(server) do
    GenServer.call(server, :stop)
  end

  ##服务器端回调
  def init(events) do
    #2.初始化回调将接受到这个事件管理器。
    #我们也把管理器状态从元组更改为map,这样将来增加新的字段时就不需要重写所有的回调。
    names = HashDict.new
    refs  = HashDict.new
    {:ok, %{names: names, refs: refs, events: events}}
  end

  def handle_call({:lookup, name}, _from, state) do
    {:reply, HashDict.fetch(state.names, name), state}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_cast({:create, name}, state) do
    if HashDict.get(state.names, name) do
      {:noreply, state}
    else
      {:ok, pid} = KV.Bucket.start_link()
      ref = Process.monitor(pid)
      refs = HashDict.put(state.refs, ref, name)
      names = HashDict.put(state.names, name, pid)
      #3. 创建时给事件管理者推送通知
      GenEvent.sync_notify(state.events, {:create, name, pid})
      {:noreply, %{state| names: names, refs: refs}}
    end
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    {name, refs} = HashDict.pop(state.refs, ref)
    names = HashDict.delete(state.names, name)
    #4. 退出时给事件管理者推送通知
    GenEvent.sync_notify(state.events, {:exit, name, pid})
    {:noreply, %{state| names: names, refs: refs}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end