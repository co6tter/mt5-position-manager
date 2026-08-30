# MT5 Position Manager 仕様

## 目的

既存の保有ポジションを、Symbol・売買方向・Ticketで安全に選択し、決済またはSL/TP変更する。EA自身は新規エントリーを行わない。

## 対象選択

- 条件指定はSymbolとLong / Short / Bothを使用する。
- 個別操作は現在のポジション行をクリックしてTicket単位で選択する。
- 表示件数を超えるポジションはページングし、選択件数・総件数を常時表示する。
- 操作前にTicket一覧をスナップショットし、走査中にインデックスを削除しない。
- hedging口座では同一Symbolの複数Ticketを個別に処理する。netting口座ではMT5の単一Symbolポジションの仕様に従う。

## Trade結果

`CTrade`のメソッドのbool戻り値だけで成功判定せず、`ResultRetcode()`と説明、Deal、Orderを確認する。決済はTicket指定の`PositionClose(ticket)`、変更はTicket指定の`PositionModify(ticket, sl, tp)`を使用する。

一時エラーはTimer駆動キューへ登録し、EAスレッドを停止せずに再試行する。`PLACED`および既存Close Orderは重複送信せず、ポジション状態だけを確認する。

## SL / TP

Price入力またはPoints入力を受け付ける。Pointsの基準価格はLongがBid、ShortがAskである。設定前に方向、Stops Level、Freeze Level、Tick Size、Digitsを検証し、Tick Sizeに合わせて正規化する。不正な選択群が1件でもあれば、グループ全体の変更要求を送信しない。

## Auto Close

`SymbolInfoSessionTrade()`でサーバー時刻基準のセッションを取得する。前日から継続中の日付跨ぎセッションがあればその終了を優先し、それ以外で複数セッションがある場合は当該曜日の最終セッション終了から指定分前を実行時刻とする。OnTimerを1秒間隔で動かし、取引Tickの有無に依存しない。起動時に実行時刻を過ぎている場合は、`Do Nothing`または`Close Now`を選択する。日付単位で一度だけ実行し、決済は有限回リトライする。

## UI

標準チャートオブジェクトだけでパネルを構成する。Symbol・Directionは候補を順番に切り替えるボタンとし、SL/TPとAuto Closeの数値は編集欄から入力する。処理結果はパネルのStatusとExpertsログへ出力する。

選択中Symbolは候補配列の位置ではなく文字列で保持し、他Symbolの追加・削除によって変更しない。

## Equity Guard

口座全体の含み損益合計(全ポジションの`profit`合計、Symbol・方向によるフィルタなし)を監視し、閾値を超えたら口座内の全ポジションを自動決済する。

閾値はAmount(金額)またはPercentを選択できる。Percentは`ACCOUNT_BALANCE`(含み損益で変動しない残高)を基準とする。含み損側・含み益側は独立に設定し、値が0または未入力の側は無効。

判定はエッジトリガーとする。閾値をまたいだ瞬間に一度だけ全ポジションの決済を実行し、以後は合計がセーフゾーン(両閾値の内側)に戻るか保有ポジションが0件になるまで再実行しない。設定変更(有効/無効・モード・閾値)時は発動状態をリセットする。

Auto Closeと同様にOnTimer駆動の自動処理とし、確認ダイアログは表示しない。発動時のステータスはAuto Close/Retryのメッセージより優先して表示する。

## Trailing Stop / Break Even

対象は1つのSymbol・Directionを選択し、Auto Closeと同様に他の選択（Filter等）とは独立に保持する。

Break Evenは、現在価格と建値の差（points）がTriggerに達したら、建値からLock（points）分有利な位置をSL候補とする。Trailingは、現在価格と建値の差（points）がTrail距離に達したら、現在価格からTrail距離分のSLを候補とする。

毎tick、対象Ticketごとに両候補のうち有利な方を採用し、現在の実際のSLより厳密に有利な場合のみSLを更新する（TPは変更しない）。SLを後退させることはない。状態は保持せず、既存のSL・建値・現在価格から都度再計算する。

候補価格（Break Evenの建値ベース、Trailingの現在価格ベース）はどちらも自前で絶対値として計算し、Tick Sizeへの正規化・Stops Level・Freeze Levelチェックには既存の`CValidationService.CalculateTarget()`をAbsoluteモードで再利用する。両候補が有効な場合はより有利な方を先に検証し、Stops Level・Freeze Levelで却下されたらもう一方を検証する。両方とも却下された場合、およびそのTicketに決済・変更のリトライが残っている場合は、そのtickでは何もしない。

Auto Close・Equity Guardと同様にOnTimer駆動の自動処理とし、確認ダイアログは表示しない。発動時のステータスはAuto Close・Equity Guard・Retryのメッセージより優先度が低い。

## 非対象

新規エントリー、自動売買戦略、インジケーター、Risk %、Partial Close、Pending Order、Magic Numberフィルタ。
