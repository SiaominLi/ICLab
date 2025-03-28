# **NYCU ICLAB 2024 Autumn**  

## **學習歷程**  
我在大學部的專題研究領域為LLM，此前並未接觸過 **Verilog** 及 **IC 設計**。這門課程是我首次學習硬體描述語言，並透過多個實作 Lab 掌握 IC 設計的核心概念。  

## **課程挑戰與突破**  
☑ **初期挑戰**：  
課程前幾個 Lab 主要涵蓋 **基礎 Verilog 語法與數位邏輯電路設計**，雖然概念簡單，但對於沒有 Verilog 經驗的我而言，理解 **硬體描述語言的並行特性** 及 **電路層面的思維** 是一項挑戰。此外，早期 Lab 的 PPA 表現不佳，讓我深刻體會到 IC 設計不僅僅是撰寫 Verilog，還需要考量硬體效能的最佳化策略。  

☑ **中後期提升**：  
隨著 Lab 進入 **進階數位設計與演算法實作**，我開始能夠針對不同設計目標選擇 **合適的電路架構**，並與同學討論與優化設計，例如：  

- **高效 Sorting Network 實作**：學習如何透過 Comparators 與 Pipelining 來提升吞吐量。  
-  **Systolic Array 加速矩陣運算**：探索資料流架構，透過陣列式資料傳播 (Data Propagation)，提升 Matrix Computation 的並行處理效能。  
- **Verilog 除法器設計 (11-bit ÷ 9-bit, 7-cycle pipeline)**：透過 Pipeline Design ，在確保運算正確性的同時，最小化電路面積並縮短 Clock Period，提升硬體效率與可擴展性。


---

Week        | Course Content                                           | Lab 
:--------   |:-----                                                    | :-----
01          | Design Flow Introduction                                 | -                               
02          | Combination Syntax                                       | Lab01: SSC.v                                      
03          | Sequential Logic Design                                  | Lab02: BB.v                                            
04          | Testbench Programming Syntax                             | Lab03: TETRIS.v PATTERN.v                                          
05          | Sequential Logic Design                                  | Lab04: CNN.v                                             
06          | Memory                                                   | Lab05: TMIP.v                    
07          | Design Compiler + IP Design (DesignWare)                 | Lab06: MDC.v                         
08          | Midterm Exam + Online Test + Midterm Project             | Midterm Project: ISP.v
09          | Synthesis & Static Time Analysis + Cross Clock Domain    | Lab07: DESIGN.v (CDC)                                    
10          | Low power design                                         | Lab08: SA.v SA_wocg.v                       
11          | Design in SystemVerilog                                  | Lab09: Program.sv
12          | Verification in SystemVerilog                            | Lab10: CHECKER.sv
13          | Formal Verification (Bonus)                              | Bonus Lab: (Report)                                           
14          | APR: From RTL to GDSII                                   | Lab11: TMIP.v (APR)              
15          | APR: IR-Drop Analysis                                    | Lab12: APR                                    
16          | Final Exam + Final Project                               | Final Project: expand support for ISP.v (APR)      

---

## **課程成果與收穫**  
☑ **硬體描述語言 (HDL) 的熟練運用**：能夠使用 Verilog 設計 Sequential 與 Combinational 電路，並優化時間與資源利用率。  
☑ **數位電路設計能力提升**：從基本邏輯電路到高效能硬體架構，熟悉不同的設計方法與最佳化策略。  
☑ **PPA 觀念強化**：學習如何在 Performance 與 Area, Power 之間做權衡，設計更高效的電路。  
☑ **團隊合作與演算法討論**：與同學合作進行電路最佳化，提升對硬體演算法的理解與應用能力。  
☑ **最終成績：83 分 (A-)**：透過這門課程，我建立了扎實的 Verilog 設計基礎，累積 IC 設計的實作經驗。  
