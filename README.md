# MT5 Position Manager

保有ポジションの管理・決済専用のMetaTrader 5 Expert Advisorです。新規エントリーは行いません。

## 機能

- Symbol と Long / Short / Both による即時一括決済
- ポジション一覧からのTicket単位の複数選択・一括決済
- 選択ポジションのSL / TP一括設定・変更（Price / Points）
- 選択ポジションのSL / TP削除
- 取引セッション終了時刻を使ったAuto Close
- 口座全体の含み損益に基づくEquity Guard（緊急全決済）
- Stops Level、Freeze Level、Tick Sizeを考慮したSL / TP検証
- Trade serverのretcode確認、部分失敗の表示、有限回リトライ
- ページングによる全ポジションの確認
- Timer駆動の非ブロッキングリトライ

## 配置とコンパイル

1. `src/` のファイルをMetaTrader 5のデータフォルダ内 `MQL5/Experts/MT5PositionManager/` にコピーします。
2. `src/PositionManager.mq5` をMetaEditorで開きます。
3. Compileを実行し、エラーがないことを確認します。
4. コンパイルされたEAをチャートへ適用します。

このリポジトリにはMetaEditorのCLIコンパイラは含まれていないため、最終的なコンパイルはMT5のMetaEditorで行ってください。

Windowsでは次のPowerShellスクリプトでコンパイル結果を検証できます。

```powershell
.\scripts\compile.ps1 -MetaEditorPath "C:\Program Files\MetaTrader 5\metaeditor64.exe"
```

単語境界付きの`0 errors`を含まないコンパイルログは失敗として扱われ、`10 errors`などを成功とは判定しません。

## 使い方

EAをチャートへ適用し、AutoTradingを有効にします。SymbolやDirectionのボタンはクリックするたびに候補が切り替わります。

- `Close Now`: 上部のFilterに一致するポジションを確認後に決済します。
- ポジション行: クリックして選択・選択解除します。
- `<` / `>`: ポジション一覧のページを移動します。Page、Selected、Totalを常に確認してください。
- `Close Selected`: 選択行だけを確認後に決済します。
- `Set / Change SL` / `Set / Change TP`: 選択行を先に選び、ModeとValueを指定します。
- `Clear SL` / `Clear TP`: 選択ポジションの該当保護注文を削除します。

Points指定では、LongはBidを基準にSLを下側、TPを上側へ、ShortはAskを基準にSLを上側、TPを下側へ計算します。

## Auto Close

Auto CloseをONにし、Symbol、Direction、クローズ何分前かを指定します。セッション終了時刻は`SymbolInfoSessionTrade()`からサーバー時刻基準で取得します。前日から継続中の日付跨ぎセッションを優先し、それ以外で1日に複数セッションがある場合は当該曜日の最終セッション終了を使います。取引セッション情報が取得できない銘柄では固定時刻へのフォールバックは行いません。

表示行数は1〜50、Auto CloseのMinutes Before Closeは0〜1,440へ安全側に正規化されます。

起動時点ですでにAuto Close時刻を過ぎている場合の初期値は`Passed: Do Nothing`です。必要な場合だけ`Passed: Close Now`へ変更してください。実行済みの日は同一設定で再実行しません。

## Equity Guard

口座全体の含み損益合計を監視し、指定した閾値を超えたら口座内の全ポジションを自動決済します。Max LossとMax Profitは独立に設定でき、0または未入力の側は無効です。Amount（金額）とPercent（`ACCOUNT_BALANCE`基準の割合）を切り替えられます。

一度発動すると、合計がセーフゾーン（両閾値の内側）に戻るか保有ポジションが0件になるまで再発動しません。Auto Closeと同様に確認ダイアログは表示されません。

監視する合計は各ポジションの含み損益（`POSITION_PROFIT`）の合計であり、swapや手数料は含みません。これらを考慮したい場合は閾値を余裕を持って設定してください。

## 安全上の注意

- 実口座へ適用する前に、必ずデモ口座・ストラテジーテスターで確認してください。
- `Close Now`と`Close Selected`には確認ダイアログがあります。Equity Guardには確認ダイアログがなく、チャートのSymbolに関係なく口座内の全ポジションを決済します。
- 一括処理は部分成功を許容します。失敗TicketとretcodeはExpertsログへ出力されます。
- 再試行はEAを停止する`Sleep()`を使わず、1秒Timerから期限到来Ticketだけを処理します。
- BrokerのStops Level、Freeze Level、取引時間、約定方式によって操作が拒否される場合があります。
- Auto CloseはEA、端末、取引サーバー、通信状態に依存します。決済完了を必ず確認してください。
- EAの停止・再起動後も実行済み状態を永続化する仕様ではありません。再起動時に`Passed`設定が適用されます。

## 構成

- `src/PositionManager.mq5`: EAエントリーポイントとタイマー
- `src/PositionService.mqh`: ポジションとSymbolの収集
- `src/TradeManager.mqh`: Ticket単位の決済・変更とTrade結果確認
- `src/PositionActionService.mqh`: 一括SL / TP操作の検証・結果集計
- `src/ValidationService.mqh`: SL / TPの価格・Broker制約検証
- `src/SessionService.mqh`: 取引セッション終了時刻の取得
- `src/AutoCloseService.mqh`: Auto Closeの日次判定
- `src/EquityGuardService.mqh`: 口座全体の含み損益によるEquity Guard判定
- `src/UiPanel.mqh`: チャートオブジェクトによる操作パネル
- `src/Models.mqh`, `src/Constants.mqh`: 共通モデルと補助関数
- `scripts/compile.ps1`: MetaEditorコンパイル検証
- `tests/`: Pure Testsとデモ口座向け手動テスト計画

## 非対象

新規Buy / Sell、自動エントリー、戦略、インジケーター、ロット計算、Partial Close、Pending Order管理、Magic Numberフィルタは対象外です。
