/// Os três estados de qualquer dado que vem de fora: carregando, pronto ou erro.
///
/// É o que o app usa no lugar do `AsyncValue` do Riverpod (ver ADR.md): a tela faz um
/// `switch` e o compilador obriga a tratar os três casos, então não sobra tela branca.
sealed class AsyncState<T> {
  const AsyncState();
}

class AsyncLoading<T> extends AsyncState<T> {
  const AsyncLoading();
}

class AsyncData<T> extends AsyncState<T> {
  const AsyncData(this.value);

  final T value;
}

class AsyncError<T> extends AsyncState<T> {
  const AsyncError(this.error);

  final Object error;
}
