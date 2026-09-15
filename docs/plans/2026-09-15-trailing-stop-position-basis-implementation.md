# 実装計画

## 目的

Trailタブに、Break Even・Trailingの計算基準を「平均建値」と「各ポジションの建値」から選ぶボタンを追加する。複数ポジションを保有していても、各Ticketの利益条件に応じてSLを設定できるようにする。選択操作と既存の数値入力が、最小パネル幅560pxでも重ならず使えることを必須とする。

## 現状

- `src/TrailingStopService.mqh`の`CTrailingStopService::Evaluate()`は、同じSymbol・売買方向のポジションをまとめ、`PMBuildPositionBasket()`でVolume加重平均建値を計算している。BuyとSellは別集計で、単純平均ではない。
- Break Evenは平均建値からTriggerに到達すると平均建値±Lockを候補にする。Trailingは平均建値からTriggerに到達し、候補が平均建値より不利でない場合に現在価格∓Distanceを候補にする。
- 両方が有効なら有利な候補を選び、検証で拒否された場合はもう一方を試す。共通候補を各Ticketへ送る前に実際のSLと比較するため、既に有利なSLを持つTicketは更新されず、結果として全TicketのSLが必ず同値になるわけではない。TPは各Ticketの値を保持する。
- バスケット内に`CTradeManager::HasPending()`が真になるTicketが1件でもあれば、そのバスケット全体をスキップする。
- `src/Models.mqh`の`TrailingStopConfig`には基準の選択項目がない。`src/UiPanel.mqh`はSymbol・Direction、BE/TrailingのON/OFF、4つの数値設定を保持し、`GetTrailingStopConfig()`でpipsをpointsへ変換する。Trailing Triggerが0ならDistanceを開始条件に使う。
- 現行UIはScope・BE・Trailing・説明の配置で、数値入力幅は`PM_TRAIL_INPUT_WIDTH=60`、本文高は`PM_PANEL_TRAIL_HEIGHT=108`。新ボタンに加え、既存の数値欄と増減ボタンの間隔も見直す必要がある。
- `src/PositionManager.mq5`は1秒Timerでリトライ処理、自動決済評価を経てTrailを評価する。新規Trail要求より先に既存のリトライが実行される。
- 純粋関数のテストは`tests/PositionManagerPureTests.mq5`、画面・取引の手動確認は`tests/manual-test-plan.md`にある。Pythonの既存テストランナーは価格編集関連のみを実行し、Trailの評価処理は対象外。

## スコープ

### 対象

- BE・Trailing共通の計算基準を選ぶボタン、設定モデル、サービスへの受け渡し。
- 平均基準の維持と、Ticket単位の発動判定・候補計算・検証・更新。
- Trailタブの行配置、数値入力幅、本文高、表示切替、移動・リサイズ対応。
- 両モードのテストと利用説明の更新。

### 対象外

- Ticketごとに異なるTrigger・Lock・Distanceを入力する機能、Ticket選択UI。
- BEとTrailingで別々の基準を選ぶ機能。
- チャート上のEquity / Break-evenラインや、SL/TPタブの手動操作の変更。
- 設定の新規永続化、取引リトライ機構全体の改修、口座方式の変更。
- このプラン作成時点での製品コード変更。

## 前提

- 「各ポジションごと」は、共通の数値設定を各Ticketの建値に対して評価する意味とする。
- 基準ボタンはBE・Trailingで1つを共有する。初期値は互換性を保つ「平均建値」。英語UIの表示案は`Basis`ラベルと、クリックで`Average` / `Per Position`が交互に切り替わるボタン。
- タブ切替・移動・折り畳み・リサイズでは基準を保持する。EA再初期化時は既存のTrail設定と同じライフサイクルに従い、平均基準へ戻す。
- 稼働中も基準を変更できる。次回Timerの新規評価から反映し、切替そのものでは取引要求を出さず、既存SL・TPやON/OFF・入力値を変更しない。
- 切替前にキューへ入った要求は既存のリトライ規則に従って完了させる。基準切替を過去の要求の取消しとは扱わず、この点を利用説明に記載する。
- Trailingの個別基準は、発動条件と建値より不利にしない条件をTicketごとに判定する。追従候補自体は現在価格∓Distanceなので、同じSymbol・方向で条件を満たしたTicket同士は同じSL候補になり得る。
- 複数Ticketの実機検証にはhedgingのデモ口座を使う。nettingの単一ポジションでは両基準が同じ結果になることを確認する。

## 未解決の疑問・矛盾

- 過去のTrail実装計画には個別基準の記述があるが、現在の実装・READMEは平均基準で一致している。本計画は現在のコードを起点にする。
- `docs/specification.md`にはTicketごとの候補検証と記載されている一方、現行サービスは代表ポジションで共通候補を検証した後、各TicketのSLを比較して送信している。平均基準の処理を不用意に変更せず、今回の仕様更新ではこの実態と新しい個別検証を区別する。
- 実際の文字幅・表示倍率による見え方はMT5での確認が必要。下記の配置寸法は初期案であり、最小幅と最大桁数を満たすよう実機で調整する。

## 受け入れ条件

1. 初期表示は`Average`で、1クリックにつき`Per Position`との切替が1回発生し、表示と`TrailingStopConfig`の値が一致する。
2. 平均基準では同一Symbol・方向のVolume加重平均建値、候補選択、バスケット単位のpending除外が従来どおり働く。Lotの異なる複数ポジションで確認する。
3. 個別基準のBEでは、各Ticket自身の建値からTriggerへ到達したTicketだけに、その建値±LockのSL候補を適用する。他Ticketが発動しても未到達Ticketは更新しない。
4. 個別基準のTrailingでは、各Ticket自身のTrigger条件と建値保護条件の両方を満たしたTicketだけが現在価格∓Distanceで追従する。BEとの候補比較・検証失敗時の代替候補もTicketごとに行う。
5. Buy・Sell双方で、SL未設定からの設定、既存SLより有利な場合だけの更新、TP保持が成立する。価格反転や基準切替だけでSLを不利な側へ戻さない。
6. 個別基準ではpendingのTicketだけを除外し、同じSymbol・方向の他Ticketは評価する。決済保護対象への変更要求や、同一Ticketへの重複要求を送らない。
7. 対象外Symbol・Direction、0件、発動条件未達では新規変更要求が出ない。消滅したTicketや無効な価格・Point、検証拒否・送信失敗があっても他の対象Ticketの処理を継続する。
8. 単一ポジションでは両基準の候補と更新結果が一致する。両方OFF、BE Trigger=0、BE Lock=0、Trailing Trigger=0時のDistance利用、Distance=0の既存挙動を維持する。
9. 切替後の新規要求は選択中の基準を使い、切替前のpending要求は既存規則で扱う。入力確定・数値増減・Symbol/Direction変更によって基準が意図せず戻らない。
10. 幅560・800・1200px、表示倍率100・125・150%で、ボタン全文、最大値`1000000`、数値欄、増減ボタン、ラベル、説明、Statusが重ならずパネル内に収まる。
11. Trail以外のタブと折り畳み中には追加部品が表示されない。再表示・移動・リサイズ後も配置と選択状態が一致し、必要本文高より小さく縮まない。既存5タブの配置を崩さない。
12. EAとPure TestsのMQL5コンパイルが成功し、追加・既存の関連テストが成功する。未実行の実機確認は成功扱いせず記録する。

## 影響範囲

| 区分 | 確認済みの対象 | 変更・確認内容 |
| --- | --- | --- |
| 直接変更 | `src/Models.mqh` | 基準を表す列挙型と`TrailingStopConfig`のフィールドを追加。ゼロ初期化で平均基準となる定義にする |
| 直接変更 | `src/TrailingStopService.mqh` | 基準に応じた平均／Ticket単位の評価。既存の候補計算・検証・取引APIを再利用 |
| 直接変更 | `src/UiPanel.mqh` | 初期化、ボタン生成・イベント・表示更新、設定受け渡し、タブ表示管理、Trailの行配置 |
| 直接変更 | `src/Constants.mqh` | Trailの座標・入力幅・本文高。最小／最大パネル幅は維持 |
| 間接確認 | `src/PositionManager.mq5` | 設定受け渡しと1秒Timer順序、Status優先順位が維持されることを確認 |
| 再利用 | `src/TradeManager.mqh`、`src/ValidationService.mqh` | `HasPending()`、`ModifyTicket()`、`CalculateTarget()`。原則として変更不要 |
| テスト | `tests/PositionManagerPureTests.mq5`、`tests/manual-test-plan.md` | 計算基準の差、境界、pending、画面の確認ケース |
| ドキュメント | `README.md`、`docs/specification.md` | 選択方法、計算基準、Trailingの共通候補になる条件、切替とpendingの扱い |

## 実装ステップ

1. **設定モデルと初期値を追加する。** `Models.mqh`に平均／個別の2値を定義し、`TrailingStopConfig`へ追加する。`UiPanel.mqh`で保持して`GetTrailingStopConfig()`から渡す。既存のpips変換とTriggerの補完を維持する。
2. **サービスへ個別評価を追加する。** 平均基準は現行のバスケット経路を保つ。個別基準ではSymbol・Directionで絞り、Ticket単位でpendingを除外し、最新のポジションを取得して建値・現在価格から候補を計算する。無効データを除外し、既存純粋関数による有利な候補選択、Absolute検証、代替候補、正規化後SL比較、TP保持、結果集計の順で処理する。候補計算の重複を抑えるための小さな共通化に留める。
3. **基準ボタンと行配置を追加する。** 既存の`CreateButton()`、`CreateNumericInput()`、オブジェクト登録を利用し、`HandleChartEvent()`、表示更新、`ApplyTabVisibility()`まで接続する。BE/TrailingのON/OFFの赤・緑は維持し、基準ボタンは通常の選択ボタンとして文字で現在値を示す。

   初期配置案（Yは`ContentTop()`からの相対値）：

   | Y | 内容 |
   | --- | --- |
   | 0 | `Scope`、Symbol、Direction |
   | 32 | `Basis`、`[Average]`または`[Per Position]` |
   | 64 | `Break Even`、ON/OFF |
   | 96 | Triggerのラベルと`- [値] +`、Lockのラベルと`- [値] +` |
   | 128 | `Trailing`、ON/OFF |
   | 160 | Triggerのラベルと`- [値] +`、Distanceのラベルと`- [値] +` |
   | 192以降 | pips単位・Trigger=0時の説明。必要なら短い2行に分ける |

   - 基準ボタンは約160px幅、数値編集欄は約120px幅を初期案とし、既存の増減ボタン込みで配置する。ラベルを含めた2組が560px内に収まるよう間隔を決める。
   - 説明末尾と余白から`PM_PANEL_TRAIL_HEIGHT`を更新し、`ContentHeight()`と`UpdateStatusLayout()`によるStatus・パネル必要高の計算へ反映する。単にボタンを追加して本文高108pxを残さない。
   - 最大桁数と表示倍率で2組が収まらない場合は入力グループ単位で行を分け、本文高を増やす。文字や入力値を切り詰めて収めない。
4. **純粋関数とモード差のテストを追加する。** 既存のBE・Trailing・バスケット・有利なSLのテストを維持する。モードから参照建値と対象Ticketを選ぶ本番ロジックをテスト可能な単位にし、片方だけが条件達成したケースを通す。候補関数へ異なる建値を渡すだけで、サービスのモード分岐検証を済ませたことにはしない。
5. **仕様と手動テストを更新する。** 平均基準の既存ケースを残し、個別基準・稼働中切替・pendingの除外単位・画面操作を追加する。Lock=0は建値SLとして有効であるため、既存手動テストの「全入力の0/空欄で無効」という読め方も項目別に明確化する。
6. **コンパイル・実機検証を行う。** 以下の検証を実施し、価格計算、対象Ticket、Expertsログ、画面を照合する。画面の寸法調整後は最小幅で再確認する。

## 検証

### 計算と対象選択

再現用の例として、5桁銘柄のBuyをA: 1 lot・建値1.10000、B: 3 lots・建値1.10200、現在Bid1.10300とする。Trigger=20 pips、Lock=2 pips、Distance=10 pipsとし、取引制約を満たす環境で評価する。

| 設定 | 平均基準（平均建値1.10150） | 個別基準 |
| --- | --- | --- |
| BEのみ | 平均の利益15 pipsなので発動しない | Aのみ発動しSL候補1.10020、Bは未更新 |
| Trailingのみ | 平均の利益15 pipsなので発動しない | Aのみ発動しSL候補1.10200、Bは未更新 |
| BEのみ・Bid1.10400 | 共通SL候補1.10170 | Aは1.10020、Bは1.10220 |
| Trailingのみ・Bid1.10400 | 共通SL候補1.10300 | A・Bとも1.10300。個別基準でも一致し得る |

- 各行は独立した初期SLから確認する。Sellの対称ケース、BothでのBuy/Sell分離、対象外Symbolを追加する。
- Trigger直前・一致・直後、浮動小数点誤差、TriggerよりDistanceが大きい場合の建値保護、BE/Trailing同時ONと片方の候補検証失敗、SL未設定・既により有利なSLを確認する。
- 0件・1件、不正価格・Point取得失敗、Ticket消滅、Stops/Freeze Level拒否、Tick Size正規化、部分成功を確認する。
- pendingが1件ある同方向2Ticketで、平均基準は両方除外、個別基準はpendingのないTicketを評価する。決済要求、変更要求、切替前からのpendingをそれぞれ確認する。

### コンパイル・既存テスト

- WindowsのMetaEditorで`src/PositionManager.mq5`と`tests/PositionManagerPureTests.mq5`をコンパイルし、`0 errors`を確認する。任意のCLI確認は既存`README.md`記載の`.\scripts\compile.ps1 -MetaEditorPath ...`を使用し、Pure Testsには`-SourcePath ".\tests\PositionManagerPureTests.mq5"`を指定する。MetaEditorのパスは実環境のものを使う。
- コンパイルとは別にMT5でPure Testsを実行し、失敗0件を確認する。
- 既存価格編集の回帰確認には`rtk proxy python3 tests/run-price-editor-tests.py`を使える。このコマンドの成功をTrailのモード分岐・MQL5コンパイル・取引API・レイアウトの成功とは扱わない。
- 専用の静的解析・型チェック設定は確認できていない。MQL5コンパイルで型整合性を確認する。このプラン作成ではテスト・実機検証は実施しない。

### 画面と回帰

- 幅560・800・1200pxと表示倍率100・125・150%を組み合わせ、最大数値、両方のボタン表記、説明、長いStatusを確認する。
- 6タブの切替、折り畳みと復帰、パネル移動、縦横リサイズ、時間足変更による再初期化を確認する。再初期化では平均基準へ戻ることを確認する。
- 各数値欄の手入力確定と増減、Symbol/Direction変更、稼働中の基準切替を確認する。
- Auto Close・Equity Guard・リトライと同時に動かして、決済対象への新規SL変更の抑止と既存Status優先順位を確認する。SL/TP手動操作とEquity / Break-evenラインの挙動が変わらないことも確認する。

## リスク

- **個別基準ならSL価格も必ず別になるという誤解** — Triggerの評価単位とTrailing候補の式を説明し、候補が一致する例もテストに含める。
- **平均基準の回帰** — 平均の経路を保ち、Lotが異なるケース、pendingのバスケット除外、既存SLが有利なケースを比較する。
- **基準切替時の既存要求との混同** — 切替は新規評価へ適用することを明記し、先に処理されるリトライと新規Trail要求をログで分けて確認する。
- **Ticket単位処理による決済との競合** — pending判定と最新Ticket取得を維持し、決済保護対象を必ず除外する。
- **UI部品の重なり・非表示漏れ** — 行を分け、入力幅と本文高を合わせて更新し、最大桁数・高DPI・全タブ切替で確認する。
- **純粋テストだけでは取引や描画の不具合を検出できない** — MT5でのコンパイル、hedgingデモ口座の取引確認、画面確認を実装完了条件に含める。
