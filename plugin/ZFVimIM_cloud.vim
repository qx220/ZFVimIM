
" ============================================================
" cloudOption: {
"   'mode' : '(optional) git/local',
"   'cloudInitMode' : '(optional) forceAsync/forceSync/preferAsync/preferSync',
"   'dbId' : '(required) dbId generated by ZFVimIM_dbInit()'
"   'repoPath' : '(required) git/local repo path',
"   'dbFile' : '(required) db file path relative to repoPath, must start with /',
"   'dbCountFile' : '(optional) db count file path relative to repoPath, must start with /',
"   'gitUserEmail' : '(optional) git user email',
"   'gitUserName' : '(optional) git user name',
"   'gitUserToken' : '(optional) git access token or password',
" }
" * for sync upload, when git user info not supplied,
"   we would ask user to input
" * for async upload, when git user info not supplied,
"   nothing would happen
function! ZFVimIM_cloudRegister(cloudOption)
    for key in ['dbId', 'repoPath', 'dbFile']
        if !exists('a:cloudOption[key]')
            echomsg '[ZFVimIM] ZFVimIM_cloudRegister: "' . key . '" is required'
            return
        endif
    endfor
    call add(g:ZFVimIM_cloudOption, a:cloudOption)

    let useAsync = 0
    if ZFVimIM_cloudAsyncAvailable()
        let cloudInitModeGlobal = get(g:, 'ZFVimIM_cloudInitMode', '')
        let cloudInitModeLocal = get(a:cloudOption, 'cloudInitMode', '')
        if 0
        elseif cloudInitModeLocal == 'forceAsync'
            let useAsync = 1
        elseif cloudInitModeLocal == 'forceSync'
            let useAsync = 0
        elseif cloudInitModeGlobal == 'forceAsync'
            let useAsync = 1
        elseif cloudInitModeGlobal == 'forceSync'
            let useAsync = 0
        elseif cloudInitModeLocal == 'preferAsync'
            let useAsync = 1
        elseif cloudInitModeLocal == 'preferSync'
            let useAsync = 0
        elseif cloudInitModeGlobal == 'preferAsync'
            let useAsync = 1
        elseif cloudInitModeGlobal == 'preferSync'
            let useAsync = 0
        endif
    endif

    if useAsync
        call ZFVimIM_initAsync(a:cloudOption)
    else
        call ZFVimIM_initSync(a:cloudOption)
    endif
endfunction
if !exists('g:ZFVimIM_cloudOption')
    let g:ZFVimIM_cloudOption = []
endif


" ============================================================

function! ZFVimIM_download()
    if ZFVimIM_cloudAsyncAvailable()
        call ZFVimIM_downloadAllAsync()
    else
        call ZFVimIM_downloadAllSync()
    endif
endfunction
function! ZFVimIM_upload()
    if ZFVimIM_cloudAsyncAvailable()
        call ZFVimIM_uploadAllAsync()
    else
        call ZFVimIM_uploadAllSync()
    endif
endfunction
command! -nargs=0 IMCloud :call ZFVimIM_upload()

function! ZFVimIM_cloudLog()
    redraw!
    for line in s:ZFVimIM_cloud_log
        echo line
    endfor
    return s:ZFVimIM_cloud_log
endfunction
command! -nargs=0 IMCloudLog :call ZFVimIM_cloudLog()


if !exists('s:ZFVimIM_cloud_log')
    let s:ZFVimIM_cloud_log = []
endif
function! ZFVimIM_cloudLogAdd(msg)
    call add(s:ZFVimIM_cloud_log, a:msg)
endfunction
function! ZFVimIM_cloudLogClear()
    let s:ZFVimIM_cloud_log = []
endfunction

function! ZFVimIM_cloudLog_stripSensitive(text)
    return substitute(a:text, ':[^:]*@', '@', 'g')
endfunction
function! ZFVimIM_cloudLog_stripSensitiveForJob(jobStatus, textList, type)
    let len = len(a:textList)
    let i = 0
    while i < len
        let a:textList[i] = ZFVimIM_cloudLog_stripSensitive(a:textList[i])
        let i += 1
    endwhile
endfunction


function! ZFVimIM_cloud_gitInfoSupplied(cloudOption)
    return 1
                \ && !empty(get(a:cloudOption, 'gitUserEmail', ''))
                \ && !empty(get(a:cloudOption, 'gitUserName', ''))
                \ && !empty(get(a:cloudOption, 'gitUserToken', ''))
endfunction


" param:
" * 0~n : clean g:ZFVimIM_cloudOption[n]
" * cloudOption
" * none : clean all
function! ZFVimIM_cloud_dbCleanup(...)
    let cloudOptionList = []
    if a:0 > 0
        if type(a:1) == type(0)
            call add(cloudOptionList, g:ZFVimIM_cloudOption[a:1])
        else
            call add(cloudOptionList, a:1)
        endif
    else
        let cloudOptionList = g:ZFVimIM_cloudOption
    endif

    call ZFVimIM_cloudLogClear()
    for cloudOption in cloudOptionList
        let dbCleanupCachePath = ZFVimIM_cloud_dbCleanupCachePath(cloudOption)
        let dbCleanupCmd = ZFVimIM_cloud_dbCleanupCmd(cloudOption, dbCleanupCachePath)
        if empty(dbCleanupCmd)
            continue
        endif
        call ZFVimIM_cloudLogAdd(ZFVimIM_cloudLog_stripSensitive(system(dbCleanupCmd)))
    endfor
    return ZFVimIM_cloudLog()
endfunction


" ============================================================
if 0
elseif executable('py3')
    let s:py = 'py3'
elseif executable('python3')
    let s:py = 'python3'
elseif executable('py')
    let s:py = 'py'
elseif executable('python')
    let s:py = 'python'
else
    let s:py = ''
endif

function! ZFVimIM_cloud_isFallback()
    return empty(s:py)
endfunction

function! ZFVimIM_cloud_file(cloudOption, key)
    if empty(get(a:cloudOption, a:key, ''))
        return ''
    else
        return a:cloudOption['repoPath'] . a:cloudOption[a:key]
    endif
endfunction

function! s:realPath(path)
    if !exists('s:isCygwin')
        let s:isCygwin = has('win32unix') && executable('cygpath')
    endif
    if s:isCygwin
        if get(g:, 'ZFVimIM_disableCygpath', 0)
            return substitute(a:path, '\\', '/', 'g')
        else
            return substitute(system('cygpath -m "' . a:path . '"'), '[\r\n]', '', 'g')
        endif
    elseif has('win32')
        return substitute(a:path, '/', '\\', 'g')
    else
        return a:path
    endif
endfunction

function! s:randName()
    return fnamemodify(tempname(), ':t')
endfunction

let s:scriptPath = s:realPath(expand('<sfile>:p:h:h') . '/misc/')

" for debug or develop only
" see dbFunc.dbLoadNormalizePy()
function! ZFVimIM_dbNormalize(dbFile)
    if empty(s:py)
        echo '[ZFVimIM] python not available'
        return
    endif
    let result = system(s:py
                \ . ' "' . s:scriptPath . 'dbNormalize.py' . '"'
                \ . ' "' . s:realPath(a:dbFile) . '"'
                \ )
    let error = v:shell_error
    redraw!
    echo '[ZFVimIM] dbNormalize finish'
    if error != 0
        echo result
    endif
endfunction

function! ZFVimIM_cloud_dbDownloadCmd(cloudOption)
    if has('unix')
        return 'sh'
                    \ . ' "' . s:scriptPath . 'dbDownload.sh' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
    else
        return '"' . s:scriptPath . 'dbDownload.bat' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
    endif
endfunction
function! ZFVimIM_cloud_dbUploadCmd(cloudOption)
    if has('unix')
        return 'sh'
                    \ . ' "' . s:scriptPath . 'dbUpload.sh' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
    else
        return '"' . s:scriptPath . 'dbUpload.bat' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
    endif
endfunction
function! ZFVimIM_cloud_dbCleanupCheckCmd(cloudOption)
    if has('unix')
        return 'sh'
                    \ . ' "' . s:scriptPath . 'dbCleanupCheck.sh' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
    else
        return '"' . s:scriptPath . 'dbCleanupCheck.bat' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
    endif
endfunction
function! ZFVimIM_cloud_dbCleanupCachePath(cloudOption)
    return s:realPath(ZFVimIM_cachePath() . '/ZFVimIM_dbCleanup_' . s:randName())
endfunction
function! ZFVimIM_cloud_dbCleanupCmd(cloudOption, dbCleanupCachePath)
    if has('unix')
        let path = split(globpath(&rtp, '/misc/git_hard_remove_all_history.sh'), '\n')
        if empty(path)
            return ''
        endif
        let path = substitute(path[0], '[\r\n]', '', 'g')
        let path = fnamemodify(fnamemodify(path, ':.'), ':p')
        return 'sh'
                    \ . ' "' . s:scriptPath . 'dbCleanup.sh' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
                    \ . ' "' . s:realPath(path) . '"'
                    \ . ' "' . a:dbCleanupCachePath . '"'
    else
        let path = split(globpath(&rtp, '/misc/git_hard_remove_all_history.bat'), '\n')
        if empty(path)
            return ''
        endif
        let path = substitute(path[0], '[\r\n]', '', 'g')
        let path = fnamemodify(fnamemodify(path, ':.'), ':p')
        return '"' . s:scriptPath . 'dbCleanup.bat' . '"'
                    \ . ' "' . s:realPath(a:cloudOption['repoPath']) . '"'
                    \ . ' "' . a:cloudOption['gitUserEmail'] . '"'
                    \ . ' "' . a:cloudOption['gitUserName'] . '"'
                    \ . ' "' . a:cloudOption['gitUserToken'] . '"'
                    \ . ' "' . s:realPath(path) . '"'
                    \ . ' "' . a:dbCleanupCachePath . '"'
    endif
endfunction

function! ZFVimIM_cloud_dbLoadCachePath(cloudOption)
    return s:realPath(ZFVimIM_cachePath() . '/ZFVimIM_dbLoad_' . s:randName())
endfunction
function! ZFVimIM_cloud_dbLoadCmd(cloudOption, dbLoadCachePath)
    if empty(s:py)
        return ''
    endif
    return s:py
                \ . ' "' . s:scriptPath . 'dbLoad.py' . '"'
                \ . ' "' . s:realPath(ZFVimIM_cloud_file(a:cloudOption, 'dbFile')) . '"'
                \ . ' "' . s:realPath(ZFVimIM_cloud_file(a:cloudOption, 'dbCountFile')) . '"'
                \ . ' "' . s:realPath(a:dbLoadCachePath) . '"'
endfunction
function! ZFVimIM_cloud_dbSaveCachePath(cloudOption)
    return s:realPath(ZFVimIM_cachePath() . '/ZFVimIM_dbSave_' . s:randName())
endfunction
function! ZFVimIM_cloud_dbSaveCmd(cloudOption, dbSaveCachePath)
    if empty(s:py)
        return ''
    endif
    return s:py
                \ . ' "' . s:scriptPath . 'dbSave.py' . '"'
                \ . ' "' . s:realPath(ZFVimIM_cloud_file(a:cloudOption, 'dbFile')) . '"'
                \ . ' "' . s:realPath(ZFVimIM_cloud_file(a:cloudOption, 'dbCountFile')) . '"'
                \ . ' "' . s:realPath(a:dbSaveCachePath) . '"'
endfunction

function! ZFVimIM_cloud_fixOutputEncoding(msg)
    if has('unix')
        return iconv(a:msg, 'utf-8', &encoding)
    else
        if !exists('s:win32CodePage')
            let s:win32CodePage = system("@echo off && for /f \"tokens=2* delims=: \" %a in ('chcp') do (echo %a)")
            let s:win32CodePage = 'cp' . substitute(s:win32CodePage, '[\r\n]', '', 'g')
        endif
        return iconv(a:msg, s:win32CodePage, &encoding)
    endif
endfunction

function! ZFVimIM_cloud_logInfo(cloudOption)
    let dbIndex = ZFVimIM_dbIndexForId(a:cloudOption['dbId'])
    if dbIndex < 0
        return '[ZFVimIM]'
    else
        return '[ZFVimIM] <' . g:ZFVimIM_db[dbIndex]['name'] . '> '
    endif
endfunction

