# MT5 Position Manager 手動テスト計画

実口座ではなくデモ口座で実施する。各ケースでExpertsログ、Status、対象Ticket、最終ポジション状態を記録する。

## コンパイル

1. `scripts/compile.ps1`で`src/PositionManager.mq5`をコンパイルし、ログが`0 errors`になることを確認する。
2. 同じスクリプトの`-SourcePath`に`tests/PositionManagerPureTests.mq5`を指定してコンパイルする。
3. Pure TestsをScriptとして実行し、すべて`[PASS]`になることを確認する。

## Symbolの安定保持

1. EURUSDとXAUUSDのポジションを用意し、FilterとAuto CloseでXAUUSDを選ぶ。
2. EURUSDだけを外部から決済する。
3. 1秒以上待ち、FilterとAuto CloseがXAUUSDのままであることを確認する。
4. XAUUSDの全ポジションを外部から決済しても、対象が別Symbolへ変化しないことを確認する。

## ページングと選択

1. 13件以上のhedgingポジションを用意する。
2. `<`と`>`ですべてのページを移動でき、全Ticketを確認できることを確認する。
3. 1ページ目と2ページ目から複数Ticketを選び、Selected件数が一致することを確認する。
4. `Close Selected`の確認ダイアログに選択した全Ticket・Symbol・方向・Lotが表示されることを確認する。
5. Noを選択し、1件も決済されないことを確認する。

## リトライ

1. 市場休止、通信切断、価格変動など、再試行対象のretcodeをデモ環境で再現する。
2. 初回失敗後もUIとページ操作が応答することを確認する。
3. `InpRetryIntervalSeconds`ごとに期限到来Ticketだけが再試行されることを確認する。
4. `INVALID_STOPS`など恒久エラーが再試行キューへ入らないことを確認する。
5. `PLACED`または既存Close Orderでは同じClose要求を再送せず、状態確認だけを行うことを確認する。
6. SL / TP変更が再試行待ちの間に別のSL / TP操作を行い、古い要求が破棄されて最新の要求だけが反映されることを確認する。

## SL / TPと消失Ticket

1. Long / Short混在選択でPrice・Pointsの有効値を設定する。
2. 1件を検証後・要求前に外部決済し、そのTicketが失敗としてStatusまたはログへ残ることを確認する。
3. Stops Level、Freeze Level、Tick Sizeに違反する値で取引要求が送信されないことを確認する。
4. Clear SL / Clear TPで反対側の値が維持されることを確認する。

## Auto Close

1. 通常セッション、複数セッション、日付跨ぎセッションでToday's CloseとAuto Close Atを確認し、複数セッションでは最初の中断時刻ではなく最終セッション終了が選ばれることを確認する。
2. 実行時刻前から稼働した場合、指定Symbol・方向だけが対象になることを確認する。
3. 実行時刻後の起動で`Do Nothing`と`Close Now`がそれぞれ設定通りになることを確認する。
4. 同一日の多重実行と再試行上限を確認する。
5. Minutes Before Closeへ負数・非数値・1,440超を入力し、0〜1,440へ正規化されることを確認する。
