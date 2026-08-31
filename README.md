# MT5 Position Manager

## Overview

保有ポジションの管理・決済とチャート上からの成り行きエントリーを行うMetaTrader 5 Expert Advisorです。Symbol、売買方向、Ticketを指定した手動操作に加え、Auto Close、Equity Guard、Break Even、Trailing Stopを提供します。

## Tech Stack

- MQL5
- MetaTrader 5 Expert Advisor
- MQL5標準ライブラリの`Trade/Trade.mqh`（`CTrade`）
- Windows向けの任意のコンパイル検証スクリプト: PowerShell（`scripts/compile.ps1`）

## Prerequisites

- MetaTrader 5
- MetaEditor
- `scripts/compile.ps1`を使う場合はWindows PowerShell

リポジトリ内にランタイムのバージョン指定ファイルやパッケージマニフェストはありません。

## Setup

1. `src/`のファイルを、MetaTrader 5のデータフォルダ内にある`MQL5/Experts/MT5PositionManager/`へコピーします。
2. MetaEditorで`src/PositionManager.mq5`を開きます。
3. Compileを実行し、エラーがないことを確認します。
4. コンパイルされたEAをチャートへ適用し、AutoTradingを有効にします。

このリポジトリにはMetaEditorのCLIコンパイラは含まれていません。Windowsでは、MetaEditorの実行ファイルを指定して次のスクリプトでコンパイル結果を検証できます。

```powershell
.\scripts\compile.ps1 -MetaEditorPath "C:\Program Files\MetaTrader 5\metaeditor64.exe"
```

`scripts/compile.ps1`は、MetaEditorの終了コードが0以外の場合、またはログに単語境界付きの`0 errors`が含まれない場合に失敗として扱います。Pure Testsを検証する場合は`-SourcePath`に`tests/PositionManagerPureTests.mq5`を指定します。

## Usage

EAをチャートへ適用し、AutoTradingを有効にします。SymbolやDirectionのボタンはクリックするたびに候補が切り替わります。

### 手動操作

パネルは`Entry`、`Positions`、`SL/TP`、`Auto`、`Guard`、`Trail`のタブに分かれています。タイトルバーの`-`で折り畳め、折り畳み中もタイトルバーをドラッグして移動できます。

- `Entry`: チャート銘柄の最新Bid/Askを表示し、Lot、初期SL/TP（points）を指定して`BUY MARKET` / `SELL MARKET`を実行します。確認ダイアログはありません。LotとSL/TP pointsは`-` / `+`をクリックして変更でき、SL/TPは注文直前の最新価格から計算されます。0 pointsは該当SL/TPなしです。
- `Positions`: Position行をクリックして選択・選択解除します。Entry、SL、TP、Profit、Ticketは詳細行に分けて表示し、銘柄のDigitsを保持します（例: `TP=159.520`）。

- `Close Now`: 上部のFilterに一致するポジションを確認後に決済します。
- ポジション行: クリックして選択・選択解除します。
- `<` / `>`: ポジション一覧のページを移動します。Page、Selected、Totalを確認してください。
- `Close Selected`: 選択行だけを確認後に決済します。
- `Set / Change SL` / `Set / Change TP`: 選択行を先に選び、ModeとValueを指定します。
- `Clear SL` / `Clear TP`: 選択ポジションの該当保護注文を削除します。
- タイトルバー部分を左ドラッグするとパネルを移動できます。右下の`///`付近を左ドラッグすると幅と高さを変更できます。高さを広げた場合、Statusはパネル下端側へ移動します。

Points指定では、LongはBidを基準にSLを下側、TPを上側へ、ShortはAskを基準にSLを上側、TPを下側へ計算します。表示行数は3〜50、Auto CloseのMinutes Before Closeは0〜1,440へ安全側に正規化されます。

### Equity / Break-evenライン

EAを配置したチャートのSymbolに保有ポジションがある場合、全Ticketの方向とLotを合算した理論上の損益分岐価格を、チャート上へ細い薄ピンクの水平線として表示します。Buyだけ、またはSellだけの場合はLot加重平均の建値です。Buy/Sellが混在する場合はネットポジションの損益分岐価格を表示します。

対象ポジションがない場合、またはBuyとSellのLotが一致してネットLotが0の場合は、一意な損益分岐価格を計算できないためラインを表示しません。SwapとCommissionは計算に含みません。ラインは1秒Timer周期で更新され、パネルの選択タブや折り畳み状態には依存しません。

### Auto Close

Auto CloseをONにし、Symbol、Direction、クローズ何分前かを指定します。セッション終了時刻は`SymbolInfoSessionTrade()`からサーバー時刻基準で取得します。前日から継続中の日付跨ぎセッションを優先し、それ以外で1日に複数セッションがある場合は当該曜日の最終セッション終了を使います。取引セッション情報が取得できない銘柄では固定時刻へのフォールバックは行いません。

起動時点ですでにAuto Close時刻を過ぎている場合の初期値は`Passed: Do Nothing`です。必要な場合だけ`Passed: Close Now`へ変更してください。実行済みの日は同一設定で再実行しません。

### Equity Guard

口座全体の含み損益合計を監視し、指定した閾値を超えたら口座内の全ポジションを自動決済します。Max LossとMax Profitは独立に設定でき、0または未入力の側は無効です。Amount（金額）とPercent（`ACCOUNT_BALANCE`基準の割合）を切り替えられます。

一度発動すると、合計がセーフゾーン（両閾値の内側）に戻るか保有ポジションが0件になるまで再発動しません。監視する合計は各ポジションの含み損益（`POSITION_PROFIT`）の合計であり、swapや手数料は含みません。

Max Loss / Max Profitへの入力は、Tab／Enter／欄外クリックで確定するまで反映されません。Percentモードで残高が0以下の場合は閾値を計算できないため、含み損があれば安全側に倒してMax Lossを発動します。

### Trailing Stop / Break Even

Break EvenとTrailingは1つのSymbol・Direction選択を共有し、Filter・Auto Close・Equity Guardの選択とは独立です。

Break Evenは、現在価格が建値からTrigger（points）以上有利に動いたら、建値からLock（points）分有利な位置へSLを移動します。Trailingは、現在価格が建値からDistance（points）以上有利に動いたら、現在価格からDistance分のSLで追従を開始します。どちらも1秒Timer周期で再計算され、SLが後退しないように更新されます。TPは変更しません。

両方を同時に有効にした場合は、その時点でより有利な方を採用します。Stops Level・Freeze Levelにより更新が拒否される場合は、もう一方の候補を試し、両方とも拒否された場合は次のTimer周期で再試行します。決済または変更に未解決の要求が残っているTicketは対象から除外されます。

TriggerやDistanceがブローカーのStops Levelより小さい場合、候補が却下されてSLが動かないことがあります。ブローカーのStops Level以上の値を設定してください。Trigger pts / Lock pts / Distance ptsへの入力は、Tab／Enter／欄外クリックで確定するまで反映されません。

### 安全上の注意

- 実口座へ適用する前に、必ずデモ口座・ストラテジーテスターで確認してください。
- `Close Now`と`Close Selected`には確認ダイアログがあります。Auto CloseとEquity Guardには確認ダイアログがなく、Equity GuardはチャートのSymbolに関係なく口座内の全ポジションを決済します。
- 一括処理は部分成功を許容します。失敗TicketとretcodeはExpertsログへ出力されます。
- 再試行はEAを停止する`Sleep()`を使わず、1秒Timerから期限到来Ticketだけを処理します。決済未完了Ticketは成功するまで決済意図を保持し、Trailing / Break Evenの変更対象から除外されます。
- BrokerのStops Level、Freeze Level、取引時間、約定方式によって操作が拒否される場合があります。
- Auto CloseはEA、端末、取引サーバー、通信状態に依存します。決済完了を必ず確認してください。
- EAの停止・再起動後も実行済み状態を永続化する仕様ではありません。再起動時に`Passed`設定が適用されます。

### 成り行きエントリーの注意

成り行き注文は`CTrade::Buy` / `Sell`へ同期送信し、retcode、Deal、Order、約定価格を確認します。BrokerのVolume Min/Max/Step、Stops Level、Freeze Level、Tick Size、取引時間、Algo Trading設定により拒否される場合があります。netting口座では反対売買が既存ポジションの決済または反転になることがあります。実口座へ適用する前に必ずデモ口座で確認してください。

### 非対象

自動売買戦略、インジケーター、Risk %、Partial Close、Pending Order管理、Magic Numberフィルタは対象外です。

## Directory Structure

```text
.
├── src/
│   ├── PositionManager.mq5       # EAエントリーポイントとタイマー
│   ├── PositionService.mqh       # ポジションとSymbolの収集
│   ├── TradeManager.mqh          # Ticket単位の決済・変更とTrade結果確認
│   ├── PositionActionService.mqh # 一括SL / TP操作の検証・結果集計
│   ├── ValidationService.mqh     # SL / TPの価格・Broker制約検証
│   ├── SessionService.mqh        # 取引セッション終了時刻の取得
│   ├── AutoCloseService.mqh      # Auto Closeの日次判定
│   ├── EquityGuardService.mqh    # Equity Guard判定
│   ├── EquityLineService.mqh     # チャートSymbolの損益分岐ライン
│   ├── TrailingStopService.mqh   # Break Even・Trailing StopのSL更新
│   ├── UiPanel.mqh               # チャートオブジェクトによる操作パネル
│   └── Models.mqh / Constants.mqh # 共通モデルと補助関数
├── scripts/compile.ps1           # MetaEditorコンパイル検証
├── tests/                        # Pure Testsと手動テスト計画
├── docs/specification.md         # 仕様書
├── LICENSE
└── README.md
```

## License

MIT
