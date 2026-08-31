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

## Tab、折り畳み、成り行きエントリー

1. 6タブを切り替え、選択中タブの本文だけが表示されることを確認する。
2. EntryタブでLot、SL/TP pointsを編集し、`-` / `+`クリックでVolume Stepまたは1 pointずつ変化することを確認する。
3. Buy/Sellそれぞれで最新Bid/Ask基準のSL/TPプレビューを確認し、0 points、SLのみ、TPのみ、SL/TP両方をデモ口座で実行する。
4. 成功時にStatusとExpertsログへside、symbol、要求Lot、結果Lot、約定価格、Deal、Order、retcodeが記録されることを確認する。部分約定は失敗表示にならないことを確認する。
5. Lotへ空欄・文字列・0、SL/TP pointsへ小数・負数・文字列を入力し、注文要求が送信されず理由がStatusへ表示されることを確認する。Algo Trading無効、Stops Level違反でも同様に確認する。
6. タイトルバーの`-`で折り畳み、タイトルと`+`以外が消えることを確認する。展開ボタン以外のタイトルバーをドラッグして移動し、`+`で再展開できることを確認する。
7. チャートSymbolに複数の同方向ポジションを作り、Lot加重平均建値に幅1pxの薄いピンクのEquity / Break-even水平線が表示されることを確認する。
8. Buy/Sell混在時はネットポジションの損益分岐価格へ移動し、ネットLotが0または対象ポジションが0件になるとラインが消えることを確認する。
9. タブ切替、パネル折り畳み、移動、リサイズ、時間足変更を行ってもラインが表示され、ポジション変更後1秒以内に更新されることを確認する。

## ページングと選択

1. 13件以上のhedgingポジションを用意する。
2. `<`と`>`ですべてのページを移動でき、全Ticketを確認できることを確認する。
3. 1ページ目と2ページ目から複数Ticketを選び、Selected件数が一致することを確認する。
4. `Close Selected`の確認ダイアログに選択した全Ticket・Symbol・方向・Lotが表示されることを確認する。
5. Noを選択し、1件も決済されないことを確認する。
6. Filter、Page、Select All、Clear、Close Selectedの各コントロールと、先頭Position行が重ならないことを確認する。
7. 右下の`///`を斜めにドラッグし、パネルの幅と高さを拡大・縮小できることを確認する。必要な本文より小さくならず、高さを広げてもStatusとリサイズグリップがパネル内にあることを確認する。

## リトライ

1. 市場休止、通信切断、価格変動など、再試行対象のretcodeをデモ環境で再現する。
2. 初回失敗後もUIとページ操作が応答することを確認する。
3. `InpRetryIntervalSeconds`ごとに期限到来Ticketだけが再試行されることを確認する。
4. `INVALID_STOPS`など恒久エラーでも、対象Ticketが決済保護状態として保持され、Trailing / Break Evenが同じTicketへ変更要求を送らないことを確認する。
5. 恒久エラーの原因を解消した後、次のTimer周期で決済が再試行されることを確認する。
6. `PLACED`または既存Close Orderでは同じClose要求を再送せず、状態確認だけを行うことを確認する。
7. SL / TP変更が再試行待ちの間に別のSL / TP操作を行い、古い要求が破棄されて最新の要求だけが反映されることを確認する。

## SL / TPと消失Ticket

1. Long / Short混在選択でPrice・Pointsの有効値を設定する。
2. 1件を検証後・要求前に外部決済し、そのTicketが失敗としてStatusまたはログへ残ることを確認する。
3. Stops Level、Freeze Level、Tick Sizeに違反する値で取引要求が送信されないことを確認する。
4. Clear SL / Clear TPで反対側の値が維持されることを確認する。

## Position価格とStatus表示

1. USDJPYでTPが`159.520`のポジションを表示し、末尾の0を含む`TP=159.520`、Profit、Ticketが確認できることを確認する。
2. `SL clear stopped: trading unavailable (auto trading disabled by client)`とticket・retcodeを含む長文Statusを発生させ、Statusが複数行で全文表示されることを確認する。

## Auto Close

1. 通常セッション、複数セッション、日付跨ぎセッションでToday's CloseとAuto Close Atを確認し、複数セッションでは最初の中断時刻ではなく最終セッション終了が選ばれることを確認する。
2. 実行時刻前から稼働した場合、指定Symbol・方向だけが対象になることを確認する。
3. 実行時刻後の起動で`Do Nothing`と`Close Now`がそれぞれ設定通りになることを確認する。
4. 同一日の多重実行と再試行上限を確認する。
5. Minutes Before Closeへ負数・非数値・1,440超を入力し、0〜1,440へ正規化されることを確認する。

## Equity Guard

1. Amountモードで、含み損合計がMax Lossをまたぐ瞬間に一度だけ全ポジションが決済要求され、Expertsログの`[WARN] Equity Guard triggered...`が1件だけ出力されることを確認する（毎秒再送されないこと）。
2. 複数Symbolのポジションを保有した状態で発動させ、チャートのSymbolやFilterに関係なく口座内の全Symbolのポジションが決済されることを確認する。
3. 決済後、保有ポジションが0件になると次にポジションを開いて再度閾値を超えるまでStatusが再発動しないことを確認する。
4. 発動中（決済がリトライ待ちの状態）に閾値やモードを変更し、ラッチがリセットされて次のクロッシングで再発動できることを確認する。
5. Percentモードで、`ACCOUNT_BALANCE`基準で閾値金額に正しく換算されることを確認する（残高の変化ではなくBalanceを基準にしていること）。
6. Max Loss / Max Profit欄に非数値・負数・空欄を入力し、その側が無効（0扱い）になることを確認する。

## Trailing Stop / Break Even

1. Break Even・Trailingを両方OFFのまま複数ポジションを保有し、SLが一切変化しないことを確認する。
2. Break EvenをONにしTrigger/Lockを設定し、対象Symbol・Directionのポジションが含み益Trigger以上になった瞬間にSLが建値+Lock（Buy）または建値-Lock（Sell）へ1回だけ更新されることを確認する（Expertsログの`[INFO] Position modified...`が連続して出力されないこと）。
3. TrailingをONにしDistanceを設定し、含み益がDistance未満の間はSLが動かず、Distance以上になってから現在価格からDistance分の位置で追従を始めることを確認する。価格が反落してもSLが後退しないことを確認する。
4. Break Even・Trailing両方ONの状態で、含み益が小さい間はBreak Evenのロック位置、含み益が大きくなるとTrailingの位置に自然に切り替わることを確認する。
5. Trigger/Lock/Distance欄に非数値・負数・空欄を入力し、その機能が実質的に無効になる（SLを一切動かさない）ことを確認する。
6. 対象外のSymbol・Directionのポジションが影響を受けないことを確認する。
