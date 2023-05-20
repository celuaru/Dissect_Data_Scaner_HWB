  require ('autorun\\GHL_ClassSettings')
  require ('autorun\\ClassOpcode')  
  frmProgressDissectData  = createFormFromFile(getCheatEngineDir().."autorun\\forms\\frmProgressDissectData.frm")
  baseAddressOfStructure = 0x408AF810 --> адрес начала структуры в любой игре
  isTimerActive = false
  skipTimer = false    
  --MODE_FIND_REWRITE_REGISTERS = false
  --breakPointAddressInt3 = 0 
  instructions = {} 

  DEBUG_MODE = true
  isStopFindind = true
  local Lcomment = ''
  function log_AddComment(argComment)
    if DEBUG_MODE then
      Lcomment = Lcomment..argComment..'\r\n'
    end
  end
  
 ----------[[  Предварительная готовность   ]]--------------------
  function tryMoveNextOffsetOfStructure()   
    local bestInstruction, tableInstructionsRewrites, someWriteOpcode = getBestOpcodeAndTableRegisterRewrites(instructions, breakPointAddress)
    -- TODO: tableInstructionsRewrites содержит перезаписываемые опкоды    
    -- Если инструкций нет, то
    
    if bestInstruction == nil then    
      -- TODO: закомментить в релизе
      -- Выводит перезаписываемые регистры
      if #tableInstructionsRewrites > 0 then
         local count = #tableInstructionsRewrites
         for i =1, count do
          log_AddComment(tableInstructionsRewrites[i].AddressInstruction..' : '..tableInstructionsRewrites[i].Opcode)
         end
      end
      --'B1 '.. 
      log_AddComment(string.format('breakPointAddress = %X', breakPointAddress))
      indexStructure = indexStructure + 1
      if indexStructure > sizeStructure then
        --B2 
        log_AddComment('indexStructure > sizeStructure '..indexStructure)
        stopDissectDataScanner()
        return
      end
      log_AddComment(string.format('Next offset %X',indexStructure))
      instructions = {}
      debug_removeBreakpoint(breakPointAddress) 
      breakPointAddress = baseAddressOfStructure + indexStructure
      debug_setBreakpoint(breakPointAddress, 1, bptAccess, bpmDebugRegister)
      return
    end
    local prefixWrite = '' 
    if someWriteOpcode then
      log_AddComment('RESULT WRITE CODE: '..bestInstruction.Opcode)
      prefixWrite = 'WRITE: '
    else
      log_AddComment('RESULT READ CODE: '..bestInstruction.Opcode)
    end
    
    -- Правильно определяем смещеиня внутри структуре по рассчету адреса внутри инстуркции и сохраненного контекста регистров
    local addressInStructure = bestInstruction:getTargetAddressFromOpcode()
    local sizeValue, typeValue, sTypeValue = bestInstruction:getTypeValue() 
    --'B5 '
    log_AddComment(string.format('breakPointAddress = %X', breakPointAddress))
    
    if addressInStructure == nil then
      log_AddComment('error addressInStructure : '..bestInstruction.AddressInstruction..' - '..bestInstruction.Opcode)
    end
    
    local offset = addressInStructure - baseAddressOfStructure
    
    -- ПРАВИЛЬНЫЙ ОФФЕСТ СТРУКТУРЫ!
    indexStructure = offset
    resultText = resultText..string.format('+%X (%X): %s %s - %s\r\n', indexStructure, addressInStructure, sTypeValue, bestInstruction.AddressInstruction, bestInstruction.Opcode)
      
    local currentOpcode = bestInstruction.Opcode    
    local comment = ''
       
    
    if currentOpcode:match('cmp') or currentOpcode:match('add') or currentOpcode:match('sub') or currentOpcode:match('xor') or 
        currentOpcode:match('or ') or currentOpcode:match('and') or currentOpcode:match('not') or currentOpcode:match('test') or 
        currentOpcode:match('mulss') or currentOpcode:match('fsub') or currentOpcode:match('fadd') or currentOpcode:match('fmul') or  
        currentOpcode:match('dec') or currentOpcode:match('inc') or currentOpcode:match('fst') or currentOpcode:match('mul') 
    then          
      comment = prefixWrite..currentOpcode:match('%S.+')..' '..sTypeValue        
    else
      --log_AddComment('->>'.. currentOpcode)
      --log_AddComment('->>>>'.. sTypeValue)
      comment = prefixWrite..currentOpcode:match('%[.*%]')..' '..sTypeValue
    end    
    
    local newIndex = #tableFilteredStructure + 1
    tableFilteredStructure[newIndex] = { Offset = indexStructure, Vartype = typeValue, Comment = comment }
    
    instructions = {}
    
    indexStructure = offset + sizeValue 
    if indexStructure > sizeStructure then
      log_AddComment('B7 indexStructure > sizeStructure '..indexStructure)
      stopDissectDataScanner()
      return
    end
    debug_removeBreakpoint(breakPointAddress)
    breakPointAddress = baseAddressOfStructure + indexStructure
    debug_setBreakpoint(breakPointAddress, 1, bptAccess, bpmDebugRegister)
  end
  function stopDissectDataScanner()
     
    isStopFindind = true
    if debugTimer ~= nil then
      debugTimer.Enabled = false
      debug_continueFromBreakpoint(co_run)
    end
    
    --[[if MODE_FIND_REWRITE_REGISTERS then
      MODE_FIND_REWRITE_REGISTERS = false
      debug_removeBreakpoint(breakPointAddressInt3)      
    end]]--
    
    debug_removeBreakpoint(breakPointAddress) 
    
    frmProgressDissectData.Hide()
    
    if resultText ~= nil then
      log_AddComment(resultText) --> вывод результата с завершением отладки
    end
    
    showFilteredSctructure()
    
    print(Lcomment)
    Lcomment = ''
  end
  function startDissectDataScanner(addressStructure, argcurrentDessectDataForm)

    if classSettingsDissectDataScanner == nil then
      classSettingsDissectDataScanner = ClassSettings:New('DissectDataScanner','txt')
    end 
    
    userAskStructureName = inputQuery('Structure name', 'Input structure name:', classSettingsDissectDataScanner:Get('userAskStructureName', 'Structure'))
    if userAskStructureName == nil then
      return
    end
    
    local userAskSizeStructureInHex = inputQuery('Size of structure (in hex)', 'Size of structure (in hex):', classSettingsDissectDataScanner:Get('sizeStructure', frmProgressDissectData.CEEdit1.Text))
    if userAskSizeStructureInHex == nil then
      return
    end
    
    local userAskAccuracy = inputQuery('Input accuracy (for 1 in 10, where 1 *= 10 ms)', 'Input accuracy:', classSettingsDissectDataScanner:Get('waitTimeTillBreak', frmProgressDissectData.CETrackBar1.Position))
    if userAskAccuracy == nil then
      return
    end
    
    classSettingsDissectDataScanner:Set('waitTimeTillBreak', userAskAccuracy)
    classSettingsDissectDataScanner:Set('sizeStructure', userAskSizeStructureInHex)
    classSettingsDissectDataScanner:Set('userAskStructureName', userAskStructureName)
    classSettingsDissectDataScanner:Save() 
    
    isStopFindind = false
    tableFilteredStructure = {}
    frmProgressDissectData.Show()
    currentDessectDataForm = argcurrentDessectDataForm
    baseAddressOfStructure = addressStructure  
    
   
    frmProgressDissectData.CEEdit1.Text = userAskSizeStructureInHex
    sizeStructure = tonumber('0x'..frmProgressDissectData.CEEdit1.Text:match('%x+')) --tonumber(frmProgressDissectData.CEEdit1.Text)
    indexStructure = 0x0    --> индекс внутри структуры, который будет перемещаться вместе с breakPointAddress
    breakPointAddress = 0   --> адрес, на который сейчас постален брейкпоинт
    
    frmProgressDissectData.CETrackBar1.Position = userAskAccuracy
    waitTimeTillBreak = 10 *  tonumber(frmProgressDissectData.CETrackBar1.Position)--> частота активности смещеиня
    resultText = ''         --> конкатенация частей текста в этой переменной
    is64bits = targetIs64Bit()

    skipTimer = true
    -- Простой таймер
    if debugTimer == nil then
      debugTimer = createTimer(nil, false)
      debugTimer.OnTimer = 
      function(timer)
        
        -- Пропустить работу с таймером, пока отладчик собирает уникальные RIP
        if skipTimer or isTimerActive then
          return
        end
        
        -- Если отладчик собрал инструкции и ждет дольше Interval, то дальше отладчик заблокирован по isTimerActive
        isTimerActive = true
        tryMoveNextOffsetOfStructure()      
        isTimerActive = false
      end
    end
    
    local leftSeconds = ((sizeStructure - indexStructure) * waitTimeTillBreak)/1000
    frmProgressDissectData.CELabel_Status.Caption =
    string.format('Time left (sec): %s', leftSeconds)
    frmProgressDissectData.CEProgressbar1.Min = 0
    frmProgressDissectData.CEProgressbar1.Max = sizeStructure
    frmProgressDissectData.CEProgressbar1.Position = indexStructure
        
    if statusTimer == nil then
      statusTimer = createTimer(nil, true)
      statusTimer.OnTimer = function(timer)
        -- Количество оставшихся адресов * частоту
        local leftSeconds = ((sizeStructure - indexStructure) * waitTimeTillBreak)/1000
        frmProgressDissectData.CELabel_Status.Caption =
        string.format('Time left (sec): %s', leftSeconds)
        frmProgressDissectData.CEProgressbar1.Min = 0
        frmProgressDissectData.CEProgressbar1.Max = sizeStructure
        frmProgressDissectData.CEProgressbar1.Position = indexStructure
      end
      debugTimer.Interval = 500
    end

    debugTimer.Interval = waitTimeTillBreak
    debugTimer.Enabled = true
    breakPointAddress = baseAddressOfStructure + indexStructure
    debug_setBreakpoint(breakPointAddress, 1, bptAccess, bpmDebugRegister)
  end
  --------------------[[  SCANNER  ]]--------------------
  function onBreakFindTypeOffsetOfStructure()  
    -- Не будет выполняться с найденным RIP
    local isFindingRip = false
    local iCount = #instructions
    for i = 1, iCount do
      if instructions[i].Context.rip == RIP then 
        isFindingRip = true 
        break 
      end
    end
    if (isFindingRip) then
      debug_continueFromBreakpoint(co_run)
      return
    end
    
    local currentLine = disassemble(RIP)     
    if currentLine:match('repe') then  
        
        -- Стоим на repe много раз как на int3 бряке
        local context = getContextTable()
        local itemOpcode = ClassOpcode:New(context)
        itemOpcode.AddressInstruction, _, itemOpcode.Opcode = currentLine:match('^(.-)%-(.-)%-(.-)$') 
        
        local step = 8
        local tempRSI = bShr(RSI, step)
        local tempRDI = bShr(RDI, step)
        local tempBreakPointAddress = bShr(breakPointAddress, step)
        
        if tempRSI == tempBreakPointAddress then
          itemOpcode.ComplexOpcode = string.format('[%X]',RSI)
          itemOpcode.Opcode = 'repe ' .. itemOpcode.ComplexOpcode
          itemOpcode.RepIsReadingOpcode = true
          log_AddComment('REPE1->>')
        elseif tempRDI == tempBreakPointAddress then
          itemOpcode.ComplexOpcode = string.format('[%X]',RDI)
          itemOpcode.Opcode = 'repe ' .. itemOpcode.ComplexOpcode
          itemOpcode.RepIsReadingOpcode = false
          log_AddComment('REPE2->>')
        else
          print (string.format('error repe tempBreakPointAddress = %X, RSI = %X, RDI = %X, ECX = %X', tempBreakPointAddress, tempRSI, tempRDI, ECX))
        end              
        
        itemOpcode.RIP_isRepOcode = true  
        instructions[#instructions + 1] = itemOpcode
        log_AddComment('REPE->> FIND  ' ..itemOpcode.Opcode)
        return
    end
    local prevAddress = getPreviousOpcode(RIP)    
    local clearStringPrevAddress = disassemble(prevAddress)  
    if clearStringPrevAddress:match('repe') then
        
        -- вышли из репе на шаг инструкции как на аппараиерм бряке
        --local context = getContextTable()
        --local itemOpcode = ClassOpcode:New(context)
        --itemOpcode.AddressInstruction, _, itemOpcode.Opcode = clearStringPrevAddress:match('^(.-)%-(.-)%-(.-)$')
        --itemOpcode.RIP_isPostRepeOpcode = true 
        --instructions[#instructions + 1] = itemOpcode
        --log_AddComment('REPE->> FIND PREVIOSE '..itemOpcode.Opcode)
        return
    end  
    ---------------------------       
    -- Как обычно, на аппаратном бряке (после выполнения инструкции)
    local context = getContextTable()
    local itemOpcode = ClassOpcode:New(context)
    itemOpcode.AddressInstruction, _, itemOpcode.Opcode = clearStringPrevAddress:match('^(.-)%-(.-)%-(.-)$')    
    instructions[#instructions + 1] = itemOpcode
    
    log_AddComment(string.format('OPCODE +%X : %s: %s', indexStructure, itemOpcode.AddressInstruction, itemOpcode.Opcode))
 end
  function debugger_onBreakpoint()
    if isStopFindind then return 0 end    
    if isTimerActive then debug_continueFromBreakpoint(co_run) return 1 end
    skipTimer = true    
    --[[
    if MODE_FIND_REWRITE_REGISTERS then      
      onBreakFindRewriteRegisters()         -- int32 брекйпоинт и аппаратный
    else      
      onBreakFindTypeOffsetOfStructure()    -- аппаратный
    end  
    ]]--
    onBreakFindTypeOffsetOfStructure()
    
    skipTimer = false    
    debug_continueFromBreakpoint(co_run)
    return 1
  end
---------------------[[   USER INTERFACE  ]]---------------
  function showFilteredSctructure()

    local addressSome = getNameFromAddress(baseAddressOfStructure)  

    local newNameStructure = userAskStructureName..'_'..addressSome..'_'..#tableFilteredStructure..'_'..waitTimeTillBreak..'ms'

    if existNameStructure(newNameStructure) then
      local countName = 1
      newNameStructure = userAskStructureName..countName..'_'..addressSome..'_'..#tableFilteredStructure..'_'..waitTimeTillBreak..'ms'
      -- Будет создавать не повторяющиеся структуры
      while existNameStructure (newNameStructure) do
        countName = countName + 1
        newNameStructure = userAskStructureName..countName..'_'..addressSome..'_'..#tableFilteredStructure..'_'..waitTimeTillBreak..'ms'
      end
    end

    myStructure = createStructure(newNameStructure)
    myStructure.addToGlobalStructureList()

    --myStructure.autoGuess(addressSome, 0, sizeStructure)
    myStructure.beginUpdate()
    -- Заполнение структуры по типам, которые определил сканер

    for i,k in ipairs(tableFilteredStructure) do
      -- Проверка на поинтер
      if is64bits then 
        if tableFilteredStructure[i].Vartype == vtQword then
          if getAddressSafe('[['..getNameFromAddress(tableFilteredStructure[i].Offset + baseAddressOfStructure)..']]') then
            tableFilteredStructure[i].Vartype = vtPointer
          end
        end   
      else
        if tableFilteredStructure[i].Vartype == vtDword
          then
          if getAddressSafe('[['..getNameFromAddress(tableFilteredStructure[i].Offset + baseAddressOfStructure)..']]') then
            tableFilteredStructure[i].Vartype = vtPointer
          end
        end   
      end  
      
      local newElement = myStructure.addElement()    
      newElement.Offset = tableFilteredStructure[i].Offset
      newElement.Vartype = tableFilteredStructure[i].Vartype
      newElement.Name = tableFilteredStructure[i].Comment
    end    
    myStructure.endUpdate()

    --local structureFrm = createStructureForm(getNameFromAddress(addressSome))
    -- Выбрать структуру на форме. Через UI клик по индексу последней созданной структуры
    local structureIndex = getStructureCount() - 1
    if currentDessectDataForm ~= nil then
      currentDessectDataForm.Menu.Items[2][structureIndex+2].doClick()
    end
  end

  function showDefaultSctructure()
    local addressSome = getNameFromAddress(baseAddressOfStructure)
    myStructure = createStructure('CEautoGuessFor_' .. addressSome)
    myStructure.addToGlobalStructureList()
    myStructure.autoGuess(addressSome, 0, sizeStructure)
    local structureFrm = createStructureForm(addressSome)
    -- Выбрать структуру на форме. Через UI клик по индексу последней созданной структуры
    local structureIndex = getStructureCount() - 1
    structureFrm.Menu.Items[2][structureIndex+2].doClick()
  end
  function existNameStructure(structureName)
    local globalCount = getStructureCount()
    for i = 0, globalCount - 1 do
      if getStructure(i).Name == structureName then
        return true
      end
    end
    return false
  end
  function splitStructureName(nameStructure)
    local key, number, address, countAddres, ms = nameStructure:match('(Structure)(%d+)_(%d+)_(%d+)_(%d+)')
    return  key, number, address, countAddres, ms
  end
  function onChangeFrmProgressDissectDataTrackBar1(sender)
    if classSettingsDissectDataScanner == nil then
      classSettingsDissectDataScanner = ClassSettings:New('DissectDataScanner','txt')
    end
    classSettingsDissectDataScanner:Set('waitTimeTillBreak', frmProgressDissectData.CETrackBar1.Position)
    classSettingsDissectDataScanner:Save()
    waitTimeTillBreak = 10 * tonumber(frmProgressDissectData.CETrackBar1.Position) --> частота активности смещеиня
    if debugTimer ~= nil then
     debugTimer.Interval = waitTimeTillBreak
    end
  end
  function onChangeSizeStructureFrmDissectData(sender)
    if classSettingsDissectDataScanner == nil then
      classSettingsDissectDataScanner = ClassSettings:New('DissectDataScanner','.txt')
    end
    --sizeStructure = tonumber(frmProgressDissectData.CEEdit1.Text)  
    sizeStructure = tonumber('0x'..frmProgressDissectData.CEEdit1.Text:match('%x+')) --tonumber(frmProgressDissectData.CEEdit1.Text)
   
    classSettingsDissectDataScanner:Set('sizeStructure', frmProgressDissectData.CEEdit1.Text)
    classSettingsDissectDataScanner:Save()
  end
  function onEventShowWindow(form)
    if form.getClassName() == 'TfrmStructures2' then
      local t = createTimer()
      t.Interval = 1
      t.Enabled = true
      t.OnTimer = function(tmr)
          if form.Menu.Items[form.Menu.Items.Count -1].Caption ~= 'Scanner' then
            local mi = createMenuItem(form.Menu)
            mi.Caption = 'Scanner'
            mi.OnClick = function() startDissectDataScanner(form.Column[0].Address, form) end
            form.Menu.Items.add(mi)
          end        
          tmr.destroy()
      end
    end
  end
  registerFormAddNotification(onEventShowWindow)
  
  
  --[[ В будущем  function onBreakFindRewriteRegisters(opcode, baseAddress)      
      
    -- В этом случае мы проходим
    
    -- Сработал RIP на int3?   
       -- сохранить контекст в кеш
    -- Сработал RIP на debugRegister?
       -- сравнить по контекстур что сразу после int3 сработал ожидаемый debugRegister
    
  
    local addressOfStructure = getAddressFromOpcode(globalOpcode)        
    local size, type = GetType(globalOpcode)
    index = (address - baseAddressOfStructure) + size + 1   
    tryMoveNextOffsetOfStructure()
    
    if index > sizeStructure then
      stopScanner()
    else
      removeBreakPoint(апаратный)
      setBreakpoint(baseAddress + index)
      
      debug_setBreakpoint(breakPointAddress, 1, bptAccess, bpmDebugRegister)
      debug_removeBreakpoint(breakPointAddress) 

    end
    return 
    -- Когда есть перезаписываемые регистрыб ставим софтбряк на инструкцию выше
    local setBreakPoint(RIP, 'sotware')
    
    -- Здесь ждем пока заполнится tableRegistersRewtiter
    while () do
      -- корутина      
      -- Счетчик времени
      time =+ Time.deltaTime
      if time >= 2s then break end
    end
    -- Если же таблица регистров долго не заполнялась
    if tableRegistersRewtiter.Filling == nil then
      -- Увеличиваем на 1 байт и топаем дальше
      index = index + 1
      return
    end
    -- Если же таблица заполнилась, то получаем адрес
    address = getAddressFromOpcodeWIthRewriterRegisters(tableRegistersRewtiter)

    local size, type = GetType(opcode)
    -- Следующий индекс
    index = getOffset(baseAddress, address) + size + 1
    
    if index > sizeStructure then
      -- stopScanner()
    end
    
    removeBreakPoint(апаратный)
    removeBreakPoint(не аппаратный)  
    
    setBreakpoint(baseAddress + index)


      

    
    -- Функция, которая вычисляет адрес в опкоде и может использовать перезаписываемые регистры
    function getAddressFromOpcodeWIthRewriterRegisters(opcode, tableRegistersRewtiter)
    
    end
  end
  ]]--
 
--[[
 function OnEditChange1(sender) 
    baseAddressOfStructure = getAddress(sender.Text)
    classSettingsDissectDataScanner:Set('address', sender.Text)
    classSettingsDissectDataScanner:Save()
  end
  
  if DEBUG_MODE then
    if (frmScanner == nil) then
      frmScanner = createForm(true)
      frmScanner.centerScreen()
      
      local btnStart = createButton(frmScanner)
      btnStart.onClick = function ()
         baseAddressOfStructure = getAddress(classSettingsDissectDataScanner:Get('address', string.format('%X',baseAddressOfStructure)))
         startDissectDataScanner(baseAddressOfStructure, nil) 
        end
      btnStart.Caption = 'Start'
      
      if classSettingsDissectDataScanner == nil then
        classSettingsDissectDataScanner = ClassSettings:New('DissectDataScanner','txt')
      end
      
     local edit1 = createEdit(frmScanner)
      edit1.Text = classSettingsDissectDataScanner:Get('address', string.format('%X',baseAddressOfStructure))
      edit1.Top = 40
      edit1.OnChange = OnEditChange1  
    end
  end
  ]]--