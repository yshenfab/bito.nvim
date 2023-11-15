if vim.g.loaded_vim_bito then
    return
end

if vim.fn.has("nvim") == 1 then
    require("nvim-treesitter").define_modules({
        bito = "/usr/local/bin/bito",
    })
end

vim.g.loaded_vim_bito = 1
vim.g.bito_buffer_name_prefix = vim.g.bito_buffer_name_prefix or "bito_history_"
vim.g.vim_bito_plugin_path = vim.fn.fnamemodify(vim.fn.expand("<sfile>:p:h"), ":p")
vim.g.vim_bito_path = vim.g.vim_bito_path or "bito"
vim.g.vim_bito_prompt_append = vim.g.vim_bito_prompt_append or ""
vim.g.vim_bito_prompt_generate = vim.g.vim_bito_prompt_generate or "Please Generate Code"
vim.g.vim_bito_prompt_generate_unit = vim.g.vim_bito_prompt_generate_unit or "Please Generate Unit Test Code"
vim.g.vim_bito_prompt_explain = vim.g.vim_bito_prompt_explain or "What does that code do"
vim.g.vim_bito_prompt_generate_comment = vim.g.vim_bito_prompt_generate_comment
    or "Generate a comment for this method, explaining the parameters and output"
vim.g.vim_bito_prompt_check_performance = vim.g.vim_bito_prompt_check_performance
    or "Check code for performance issues, explain the issues, and rewrite code if possible"
vim.g.vim_bito_prompt_check = vim.g.vim_bito_prompt_check
    or "Identify potential issues that would find in this code, explain the issues, and rewrite code if possible"
vim.g.vim_bito_prompt_check_security = vim.g.vim_bito_prompt_check_security
    or "Check code for security issues, explain the issues, and rewrite code if possible"
vim.g.vim_bito_prompt_readable = vim.g.vim_bito_prompt_readable or "Organize the code to be more human readable"
vim.g.vim_bito_prompt_check_style = vim.g.vim_bito_prompt_check_style
    or "Check code for style issues, explain the issues, and rewrite code if possible"

function BitoAiGenerate()
    local input = vim.fn.input("Bito prompt：")

    if input == "" then
        print("Please Input Context!")
        return
    end

    BitoAiExec("generate", input)
end

function BitoAiSelected(prompt)
    local start = vim.fn.getpos("'<")[2]
    local end_ = vim.fn.getpos("'>")[2]
    local lines = vim.fn["getline"](start, end_)
    local text = table.concat(lines, "\n")

    if text == "" then
        return
    end

    BitoAiExec(prompt, text)
end

function BitoAiExec(prompt, input)
    local tempFile = vim.fn.tempname()
    vim.fn.writefile(vim.split(input, "\n"), tempFile)
    local common_content = vim.fn.readfile(vim.g.vim_bito_plugin_path .. "/templates/common.txt")

    if prompt == "generate" then
        common_content = vim.fn.readfile(vim.g.vim_bito_plugin_path .. "/templates/generate.txt")
    end

    if vim.fn.exists("g:vim_bito_prompt_" .. prompt) then
        local prompt_text = vim.fn.execute("echo g:vim_bito_prompt_" .. prompt) .. " " .. vim.g.vim_bito_prompt_append
    else
        print("Undefined variable: g:vim_bito_prompt_" .. prompt)
        return
    end

    local replaced_content = {}
    for _, line in ipairs(common_content) do
        local replaced_line = vim.fn.substitute(line, "{{:prompt:}}", prompt_text, "")
        table.insert(replaced_content, replaced_line)
    end

    local templatePath = vim.fn.tempname()
    vim.fn.writefile(replaced_content, templatePath)

    local cmdList = { vim.g.vim_bito_path, "-p", templatePath, "-f", tempFile }
    local job

    if vim.fn.has("nvim") == 1 then
        job = vim.fn.jobstart(cmdList, { on_stdout = "BiAsyncCallback", stdin = "null" })
    else
        job = vim.fn.job_start(cmdList, { out_cb = "BiAsyncCallback", in_io = "null" })
    end
end

function BitoAiFindBufferNo(job_id)
    local buf_list = vim.fn.tabpagebuflist()
    local buf_no = 0
    local bito_buffer_name = vim.g.bito_buffer_name_prefix .. job_id

    for _, buf in ipairs(buf_list) do
        if vim.fn.getbufvar(buf, "&filetype") == "bito" and vim.fn.bufname(buf) == bito_buffer_name then
            buf_no = buf
            break
        end
    end

    if buf_no == 0 then
        vim.cmd("vs " .. bito_buffer_name)
        vim.cmd("set filetype=bito")
        vim.cmd("setlocal norelativenumber swapfile bufhidden=hide")
        vim.cmd("setlocal buftype=nofile")
        buf_no = vim.fn.bufnr("%")
    end

    return buf_no
end

function BiAsyncCallback(job_id, data, ...)
    vim.g.bito_job_list = vim.g.bito_job_list or {}
    vim.g.bito_job_list[job_id] = vim.g.bito_job_list[job_id] or 1

    local buf_no = BitoAiFindBufferNo(job_id)

    if vim.fn.has("nvim") == 1 then
        local line_text = vim.fn.getline(buf_no, vim.g.bito_job_list[job_id])[1]
        for i, line in ipairs(data) do
            if i == 1 then
                vim.fn.setline(buf_no, vim.g.bito_job_list[job_id], line_text .. line)
            else
                vim.fn.append(buf_no, "$", line)
                vim.g.bito_job_list[job_id] = vim.g.bito_job_list[job_id] + 1
            end
        end
    else
        vim.fn.append(buf_no, "$", data)
    end
end

vim.cmd("command! -nargs=0 BitoAiGenerate :call BitoAiGenerate()")
vim.cmd('command! -range -nargs=0 BitoAiGenerateUnit :call BitoAiSelected("generate_unit")')
vim.cmd('command! -range -nargs=0 BitoAiGenerateComment :call BitoAiSelected("generate_comment")')
vim.cmd('command! -range -nargs=0 BitoAiCheck :call BitoAiSelected("check")')
vim.cmd('command! -range -nargs=0 BitoAiCheckSecurity :call BitoAiSelected("check_security")')
vim.cmd('command! -range -nargs=0 BitoAiCheckStyle :call BitoAiSelected("check_style")')
vim.cmd('command! -range -nargs=0 BitoAiCheckPerformance :call BitoAiSelected("check_performance")')
vim.cmd('command! -range -nargs=0 BitoAiReadable :call BitoAiSelected("readable")')
vim.cmd('command! -range -nargs=0 BitoAiExplain :call BitoAiSelected("explain")')
