# MT5 Position Manager 仕様

## 目的

既存の保有ポジションを、Symbol・売買方向・Ticketで安全に選択し、決済またはSL/TP変更する。Entryタブからチャート銘柄の成り行きBuy/Sellも実行する。

## 対象選択

- 条件指定はSymbolとLong / Short / Bothを使用する。Symbol候補は保有ポジションの銘柄と、同じEAパネルを表示しているチャートの銘柄から構成する。
- 個別操作は現在のポジション行をクリックしてTicket単位で選択する。
- 表示件数を超えるポジションはページングし、選択件数・総件数を常時表示する。
- 操作前にTicket一覧をスナップショットし、走査中にインデックスを削除しない。
- hedging口座では同一Symbolの複数Ticketを個別に処理する。netting口座ではMT5の単一Symbolポジションの仕様に従う。

## Trade結果

`CTrade`のメソッドのbool戻り値だけで成功判定せず、`ResultRetcode()`と説明、Deal、Order、結果Volume、結果Priceを確認する。成り行き注文は`DONE`、`DONE_PARTIAL`、`PLACED`を受付成功として扱い、自動再送しない。決済はTicket指定の`PositionClose(ticket)`、変更はTicket指定の`PositionModify(ticket, sl, tp)`を使用する。

一時エラーはTimer駆動キューへ登録し、EAスレッドを停止せずに再試行する。決済の恒久エラーも未解決の決済意図としてキューに保持し、設定間隔で再試行する。未解決の決済TicketはSL/TP自動変更の対象外とする。`PLACED`および既存Close Orderは重複送信せず、ポジション状態だけを確認する。

## SL / TP

Price入力またはPips入力を受け付ける。Pipsの基準価格はLongがBid、ShortがAskで、銘柄のDigitsに応じて内部のpointsへ変換する。設定前に方向、Stops Level、Freeze Level、Tick Size、Digitsを検証し、Tick Sizeに合わせて正規化する。不正な選択群が1件でもあれば、グループ全体の変更要求を送信しない。

## Auto Close

`SymbolInfoSessionTrade()`でサーバー時刻基準のセッションを取得する。前日から継続中の日付跨ぎセッションがあればその終了を優先し、それ以外で複数セッションがある場合は当該曜日の最終セッション終了から指定分前を実行時刻とする。OnTimerを1秒間隔で動かし、取引Tickの有無に依存しない。起動時に実行時刻を過ぎている場合は、`Do Nothing`または`Close Now`を選択する。日付単位で一度だけ決済要求を開始し、未解決TicketはTradeManagerが設定間隔で再試行する。

## UI

標準チャートオブジェクトだけでパネルを構成する。パネル内には余白を設ける。Entry、Positions、SL/TP、Auto Close、Equity Guard、Trailの6タブを持ち、選択中タブは明るい青色・強調境界線・白文字、非選択タブは暗い青灰色・控えめな境界線・銀文字で表示し、非選択タブの本文は表示しない。タイトルバーの折り畳みボタンで本文を隠せ、折り畳み中もタイトルバーをドラッグできる。右下のグリップでは幅と高さを変更でき、必要な本文より小さくはしない。Symbol・Directionは候補を順番に切り替えるボタンとし、SL/TPとAuto Closeの数値は編集欄から入力する。処理結果は本文より少し大きい、折り返し可能な複数行StatusとExpertsログへ出力する。Statusは通常を明るい色、成功・変更なしを緑、待機を黄色、失敗を赤で表示する。SL/TPの一括変更で既存値と同じTicketは`unchanged`として集計し、失敗には含めない。Positionsの価格は銘柄のDigitsで表示する。

EntryタブはLot、SL/TP points、最新Bid/Ask、Buy/Sell別の計算価格を表示する。LotはVolume Min/Max/Stepへ正規化し、SL/TPは注文直前のTickから計算してStops Level、Freeze Level、Tick Sizeを検証する。確認ダイアログは表示しない。全数値入力欄には`-` / `+`を配置し、Minutesは1分、Amountは1.00、Percentは0.1ポイント、pips欄は1 pip単位で増減する。下限・上限を超える操作は境界値で止める。

SL/TPタブのPriceモードでは、選択全件がチャート銘柄の場合に候補価格をSL/TP別の水平ラインとして表示する。ラインまたはラベルの左ドラッグ終了時に、該当入力欄へTick Size単位で反映する。`Set / Change`を押すまで取引要求は送信しない。Priceの増減は通常1 pip相当、Tick Sizeが大きい場合は最低1 tickとし、増減方向に沿って正の価格へそろえる。

描画は確定済みの入力とドラッグ候補を参照し、編集中の文字列を書き換えない。空欄時は選択全件で一致する非ゼロの既存SL/TP、または先頭選択の方向・最新Bid/Ask・Stops/Freeze Levelから候補を作るが、ドラッグ等の確定操作までは入力欄へ書き込まない。選択変更でもPrice/Pipsの入力文字列を維持する。ドラッグ中の候補はTimer更新で戻さず、選択・モード・タブ・折り畳み・チャート変更、選択Ticketの消失やVolume/建値の変更で破棄する。マウスを離したときも最新ポジションと照合する。

ラベルにはDigitsを保持した価格、選択Ticketの`OrderCalcProfit()`による口座通貨の概算合計（Swap・Commission除外）、建値からのBuy/Sell別Volume加重平均pips、件数を表示する。金額は口座通貨の表示桁数を使用し、1件でも計算失敗なら`N/A`とするがpipsは表示する。選択全件のBroker制約を満たさない候補は`Invalid`と表示する。選択なし、別銘柄、Pipsモード、タブ非表示・折り畳みでは該当ラインとラベルを隠す。不正入力や価格取得失敗はヒントへ理由を表示する。

ラインは背景の`OBJ_HLINE`、ラベルはパネルや他の編集ラベルを避ける`OBJ_LABEL`とし、同価格でもラベルからSL/TPを区別して操作できる。ネイティブのオブジェクト選択・ドラッグは使わず、`CHARTEVENT_MOUSE_MOVE`と座標変換でマウス操作を処理する。操作中はチャートスクロールを止め、終了・中断時に元へ戻す。画面に収まらない価格やラベルはヒントで知らせ、候補価格自体を画面端へ変更しない。

選択中Symbolは候補配列の位置ではなく文字列で保持し、他Symbolの追加・削除によって変更しない。

## Equity / Break-evenライン

チャートの`_Symbol`に属する全ポジションについて、Buyを正、Sellを負とした方向付きVolumeと建値の加重値から、ネットポジションの理論上の損益分岐価格を計算する。価格はTick Sizeへ正規化し、幅1pxの薄いピンクの破線`OBJ_HLINE`として全時間足へ表示する。`OBJPROP_BACK=true`でチャートの背景へ描画し、操作パネルの前景UIより背面に置く。OnInitと1秒Timerで更新し、パネルのタブ、折り畳み、移動、リサイズから独立させる。

対象ポジションがない場合、ネットVolumeが0の場合、または有効な正価格を計算できない場合はラインを非表示にして再利用し、EA終了時に削除する。SwapとCommissionは計算対象外とする。

## Equity Guard

口座全体の含み損益合計(全ポジションの`profit`合計、Symbol・方向によるフィルタなし)を監視し、閾値を超えたら口座内の全ポジションを自動決済する。

閾値はAmount(金額)またはPercentを選択できる。Percentは`ACCOUNT_BALANCE`(含み損益で変動しない残高)を基準とする。含み損側・含み益側は独立に設定し、値が0または未入力の側は無効。Percentモードで残高が0以下の場合は割合を計算できないため、含み損側は「含み損が0未満なら発動」というフェイルセーフとして動作する(安全側の挙動を優先し、無効化はしない)。

判定はエッジトリガーとする。閾値をまたいだ瞬間に一度だけ全ポジションの決済を実行し、以後は合計がセーフゾーン(両閾値の内側)に戻るか保有ポジションが0件になるまで再実行しない。設定変更(有効/無効・モード・閾値)時は発動状態をリセットする。

Max Loss/Max Profitの入力欄は、確定操作(ENDEDIT)まで値を確定しない。編集中の未確定文字列がOnTimerの判定に使われることはない。

Auto Closeと同様にOnTimer駆動の自動処理とし、確認ダイアログは表示しない。発動時のステータスはAuto Close/Retryのメッセージより優先して表示する。

## Trailing Stop / Break Even

対象は1つのSymbol・Directionを選択し、Auto Closeと同様に他の選択（Filter等）とは独立に保持する。加えて、計算基準（Basis）を`Per Position`（既定・ゼロ値）と`Average`から1つ選び、Break EvenとTrailingで共有する。`Basis`はボタンクリックのたびに交互に切り替わり、タブ切替・パネルの移動・折り畳み・リサイズでは値を保持するが、EAの再初期化では他のTrail設定と同じライフサイクルに従い`Per Position`へ戻る。稼働中の切り替えは次回のTimer評価以降の新規判定にのみ反映し、切り替え自体は取引要求を出さず、既存のSL・TP・ON/OFF・入力値を変更しない。切り替え前にキューへ入っていた再試行は、既存の再試行規則に従って完了する。

`Average`では、同じSymbol・同じDirectionのポジションを1つのバスケットとして扱い、BuyとSellは別々に集計する。バスケットのVolume加重平均建値から現在価格がBreak Even Triggerに達したら、加重平均建値からLock分有利な共通SL候補とする。Trailingはバスケットの加重平均建値から現在価格がTrailing Triggerに達したら開始し、現在価格からTrailing Distance分の共通SL候補とする。共通SLは加重平均建値より不利にはしないが、個別ポジションの建値より不利な位置になることがある。バスケット内に未解決の決済・変更要求があるTicketが1件でもある場合、その周期はバスケット全体を処理しない。

`Per Position`では、バスケットにまとめず各Ticket自身の建値・現在価格を基準に判定する。Break Evenは各Ticket自身の建値からBreak Even Triggerに達したTicketだけに、その建値からLock分有利なSL候補を適用する。Trailingは各Ticket自身がTrailing Triggerに達し、かつ候補が自身の建値より不利にならないTicketだけに、現在価格からTrailing Distance分のSL候補を適用する。追従候補自体は現在価格を基準にした共通の式であるため、同じSymbol・Directionで条件を満たした複数Ticketが同じSL候補になることがある。未解決の決済・変更要求があるTicketだけを対象から除外し、同じSymbol・Directionの他Ticketは引き続き評価する。

入力されたpipsは銘柄の桁数に応じて内部のpointsへ変換する。Trailing Triggerが0または未入力の場合は、既存動作との互換性のためTrailing Distanceを開始条件にも使用する。

1秒Timer周期ごとに、判定単位（`Average`はバスケット、`Per Position`は各Ticket）ごとに両候補のうち有利な方を採用し、対象Ticketの現在の実際のSLより厳密に有利な場合のみ、同じ候補価格でSLを更新する（TPは変更しない）。SLを後退させることはない。状態は保持せず、既存のSL・建値（`Average`は加重平均、`Per Position`は各Ticket自身）・現在価格から都度再計算する。

候補価格（Break Evenの建値ベース、Trailingの現在価格ベース）はどちらも自前で絶対値として計算し、TicketごとのTick Sizeへの正規化・Stops Level・Freeze Levelチェックには既存の`CValidationService.CalculateTarget()`をAbsoluteモードで再利用する。`Average`は代表ポジション経由でバスケット共通の候補を検証し、受理されればバスケット内の全Ticketへ同じ候補を適用する。`Per Position`は各Ticket自身を経由して個別に候補を検証し、受理されたTicketだけへ適用する。いずれも候補が検証できない場合、両方の候補（Break EvenとTrailingが両方有効なとき）を試しても変更要求を送信しない。Break Even Trigger/Lock、Trailing Trigger/Distanceの入力欄はpips単位で、Equity Guardと同様に確定操作(ENDEDIT)まで値を確定しない。

Auto Close・Equity Guardと同様にOnTimer駆動の自動処理とし、確認ダイアログは表示しない。発動時のステータスはAuto Close・Equity Guard・Retryのメッセージより優先度が低い。

## 非対象

自動売買戦略、インジケーター、Risk %、Partial Close、Pending Order、Magic Numberフィルタ。
