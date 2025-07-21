#!/bin/bash

# Enhanced Interactive Git Workflow Script
# Author: Created for comprehensive git operations with detailed explanations
# Description: Provides interactive prompts, command displays, and extensive git workflow management

set -e  # Exit on any error

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_EDITOR="${EDITOR:-nano}"
MAX_LOG_LINES=20
GIT_LOG_DIR="$HOME/.git_workflow_logs"

# Create log directory
mkdir -p "$GIT_LOG_DIR"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_question() {
    echo -e "${BLUE}[QUESTION]${NC} $1"
}

print_command() {
    echo -e "${CYAN}[COMMAND]${NC} $1"
}

print_success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1"
}

print_header() {
    echo -e "${WHITE}[HEADER]${NC} $1"
}

# Function to log workflow actions
log_action() {
    local action="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local repo_name=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null || echo "unknown")
    echo "[$timestamp] [$repo_name] $action" >> "$GIT_LOG_DIR/git_workflow.log"
}

# Function to check if we're in a git repository
check_git_repo() {
    print_command "git rev-parse --git-dir"
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository. Please run this script from within a git repository."
        print_status "To initialize a new git repository, run: git init"
        exit 1
    fi
    
    local repo_root=$(git rev-parse --show-toplevel)
    local repo_name=$(basename "$repo_root")
    print_status "Working in repository: $repo_name"
    print_status "Repository path: $repo_root"
}

# Function to show comprehensive git status
show_status() {
    print_header "=== REPOSITORY STATUS ==="
    
    # Show current branch and upstream info
    local current_branch=$(git branch --show-current)
    local upstream=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null || echo "No upstream")
    
    print_status "Current branch: $current_branch"
    print_status "Upstream: $upstream"
    
    # Show commit info
    print_command "git log --oneline -1"
    print_status "Latest commit: $(git log --oneline -1 2>/dev/null || echo 'No commits yet')"
    
    # Show working directory status
    print_command "git status --short"
    echo "─────────────────────────────"
    if [[ -z $(git status --porcelain) ]]; then
        print_success "Working directory is clean"
    else
        git status --short
    fi
    echo "─────────────────────────────"
    
    # Show stash info
    local stash_count=$(git stash list | wc -l | tr -d ' ')
    if [[ $stash_count -gt 0 ]]; then
        print_status "Stashes available: $stash_count"
    fi
}

# Function to show detailed file differences
show_diff_preview() {
    local file="$1"
    print_command "git diff --color=always '$file' | head -20"
    echo "Preview of changes in $file:"
    echo "─────────────────────────────"
    git diff --color=always "$file" | head -20
    local total_lines=$(git diff "$file" | wc -l)
    if [[ $total_lines -gt 20 ]]; then
        echo "... ($((total_lines - 20)) more lines)"
    fi
    echo "─────────────────────────────"
}

# Function to show repository information
show_repo_info() {
    echo
    print_header "=== REPOSITORY INFORMATION ==="
    
    # Remote information
    print_command "git remote -v"
    if git remote > /dev/null 2>&1; then
        print_status "Remote repositories:"
        git remote -v | while read remote; do
            echo "  $remote"
        done
    else
        print_warning "No remote repositories configured"
    fi
    
    # Branch information
    print_command "git branch -a"
    print_status "Available branches:"
    git branch -a | head -10
    
    # Recent commits
    print_command "git log --oneline -5"
    print_status "Recent commits:"
    git log --oneline -5 2>/dev/null || echo "No commits yet"
    echo
}

# Function to handle interactive file addition
interactive_add_files() {
    print_status "=== INTERACTIVE FILE SELECTION ==="
    local files=()
    
    # Get all modified/untracked files
    while IFS= read -r line; do
        files+=("$line")
    done < <(git status --porcelain | grep -E "^(\?\?|M |A | M)" | cut -c4-)
    
    if [[ ${#files[@]} -eq 0 ]]; then
        print_warning "No files available to add."
        return 1
    fi
    
    echo "Available files:"
    for i in "${!files[@]}"; do
        local status=$(git status --porcelain | grep "${files[$i]}" | cut -c1-2)
        printf "%2d) [%s] %s\n" $((i+1)) "$status" "${files[$i]}"
        
        # Show preview option
        read -p "    Preview this file? (y/N/q to quit): " preview
        if [[ "$preview" =~ ^[Yy]$ ]]; then
            show_diff_preview "${files[$i]}"
        elif [[ "$preview" =~ ^[Qq]$ ]]; then
            break
        fi
    done
    
    echo
    read -p "Enter file numbers to add (space-separated, e.g., '1 3 5'): " selections
    
    local selected_files=()
    for num in $selections; do
        if [[ $num =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#files[@]} ]]; then
            selected_files+=("${files[$((num-1))]}")
        fi
    done
    
    if [[ ${#selected_files[@]} -gt 0 ]]; then
        print_command "git add ${selected_files[*]}"
        git add "${selected_files[@]}"
        print_success "Selected files added successfully!"
        log_action "Added files: ${selected_files[*]}"
        return 0
    else
        print_warning "No valid files selected."
        return 1
    fi
}

# Function to handle patch-wise adding
handle_patch_add() {
    local file="$1"
    print_status "Starting interactive patch mode for: $file"
    print_command "git add -p '$file'"
    print_status "Use 'y' to stage hunk, 'n' to skip, 's' to split, 'q' to quit"
    git add -p "$file"
}

# Function to handle git add
handle_git_add() {
    echo
    print_header "=== GIT ADD STAGE ==="
    
    if [[ -z $(git status --porcelain) ]]; then
        print_warning "No changes detected. Nothing to add."
        return 1
    fi
    
    # Show current status with file details
    print_status "Current working directory status:"
    echo "─────────────────────────────"
    git status --porcelain | while read -r line; do
        local status=$(echo "$line" | cut -c1-2)
        local file=$(echo "$line" | cut -c4-)
        case "$status" in
            "??") echo "  [UNTRACKED] $file" ;;
            " M") echo "  [MODIFIED]  $file" ;;
            "M ") echo "  [STAGED]    $file" ;;
            "MM") echo "  [BOTH]      $file" ;;
            "A ") echo "  [ADDED]     $file" ;;
            "D ") echo "  [DELETED]   $file" ;;
            *) echo "  [$status]      $file" ;;
        esac
    done
    echo "─────────────────────────────"
    
    echo
    print_question "How would you like to add files?"
    echo "1) Add all changes                    [git add .]"
    echo "2) Add specific files (interactive)   [git add <files>]"
    echo "3) Add all tracked files only         [git add -u]"
    echo "4) Add with patch mode (per hunk)     [git add -p]"
    echo "5) Add by pattern/glob                [git add <pattern>]"
    echo "6) View detailed diff before adding   [git diff]"
    echo "7) Skip adding files"
    echo
    read -p "Enter your choice (1-7): " add_choice
    
    case $add_choice in
        1)
            print_command "git add ."
            git add .
            print_success "All changes added successfully!"
            log_action "Added all changes (git add .)"
            ;;
        2)
            interactive_add_files
            ;;
        3)
            print_command "git add -u"
            git add -u
            print_success "All tracked files added successfully!"
            log_action "Added tracked files (git add -u)"
            ;;
        4)
            echo "Available files for patch mode:"
            git status --porcelain | grep -E "^( M|MM)" | cut -c4- | nl
            read -p "Enter file name for patch mode: " patch_file
            if [[ -n "$patch_file" ]] && [[ -f "$patch_file" ]]; then
                handle_patch_add "$patch_file"
                log_action "Used patch mode on: $patch_file"
            else
                print_error "Invalid file specified."
                return 1
            fi
            ;;
        5)
            read -p "Enter pattern/glob (e.g., '*.js', 'src/'): " pattern
            if [[ -n "$pattern" ]]; then
                print_command "git add '$pattern'"
                git add "$pattern"
                print_success "Files matching pattern added successfully!"
                log_action "Added pattern: $pattern"
            else
                print_error "No pattern specified."
                return 1
            fi
            ;;
        6)
            print_command "git diff --color=always | less -R"
            git diff --color=always | less -R
            # Recursive call to choose again after viewing diff
            handle_git_add
            return $?
            ;;
        7)
            print_warning "Skipping git add stage."
            return 1
            ;;
        *)
            print_error "Invalid choice. Skipping git add stage."
            return 1
            ;;
    esac
    
    # Show what was staged
    echo
    print_command "git diff --cached --name-status"
    print_status "Files staged for commit:"
    if [[ -n $(git diff --cached --name-only) ]]; then
        git diff --cached --name-status | while read -r line; do
            echo "  $line"
        done
        
        # Offer to view staged changes
        echo
        read -p "View staged changes? (y/N): " view_staged
        if [[ "$view_staged" =~ ^[Yy]$ ]]; then
            print_command "git diff --cached --color=always | less -R"
            git diff --cached --color=always | less -R
        fi
    else
        print_warning "No files were staged."
        return 1
    fi
    
    return 0
}

# Function to generate commit message suggestions
generate_commit_suggestions() {
    local staged_files=()
    while IFS= read -r file; do
        staged_files+=("$file")
    done < <(git diff --cached --name-only)
    
    print_status "Suggested commit messages based on changes:"
    echo "─────────────────────────────"
    
    # Analyze file types and changes
    local has_docs=false
    local has_tests=false
    local has_config=false
    local has_src=false
    
    for file in "${staged_files[@]}"; do
        case "$file" in
            *.md|*.txt|*.rst|docs/*) has_docs=true ;;
            *test*|*spec*|test/*|tests/*) has_tests=true ;;
            *.json|*.yml|*.yaml|*.toml|*.ini|config/*) has_config=true ;;
            *.js|*.py|*.go|*.rs|*.java|*.c|*.cpp|src/*) has_src=true ;;
        esac
    done
    
    local suggestions=()
    if $has_docs; then suggestions+=("docs: Update documentation"); fi
    if $has_tests; then suggestions+=("test: Add/update tests"); fi
    if $has_config; then suggestions+=("chore: Update configuration"); fi
    if $has_src; then suggestions+=("feat: Add new functionality" "fix: Fix bug in implementation"); fi
    
    if [[ ${#suggestions[@]} -eq 0 ]]; then
        suggestions+=("chore: Update files" "feat: Add changes" "fix: Fix issues")
    fi
    
    for i in "${!suggestions[@]}"; do
        echo "  $((i+1))) ${suggestions[$i]}"
    done
    echo "─────────────────────────────"
}

# Function to validate commit message
validate_commit_message() {
    local message="$1"
    local warnings=()
    
    # Check length (conventional: subject line <= 50 chars)
    if [[ ${#message} -gt 50 ]]; then
        warnings+=("Subject line is longer than 50 characters (${#message} chars)")
    fi
    
    # Check for imperative mood (basic check)
    if [[ ! "$message" =~ ^(Add|Remove|Fix|Update|Refactor|Implement|Create|Delete|Merge|Revert) ]]; then
        warnings+=("Consider using imperative mood (Add, Fix, Update, etc.)")
    fi
    
    # Check capitalization
    if [[ "$message" =~ ^[a-z] ]]; then
        warnings+=("Consider capitalizing the first letter")
    fi
    
    # Check for period at end
    if [[ "$message" =~ \.$  ]]; then
        warnings+=("Consider removing the period at the end")
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        print_warning "Commit message suggestions:"
        for warning in "${warnings[@]}"; do
            echo "  - $warning"
        done
        echo
        read -p "Proceed anyway? (y/N): " proceed
        [[ "$proceed" =~ ^[Yy]$ ]]
    else
        return 0
    fi
}

# Function to handle git commit
handle_git_commit() {
    echo
    print_header "=== GIT COMMIT STAGE ==="
    
    # Check if there are staged changes
    if [[ -z $(git diff --cached --name-only) ]]; then
        print_warning "No staged changes to commit."
        return 1
    fi
    
    # Show what will be committed
    print_command "git diff --cached --stat"
    print_status "Changes to be committed:"
    git diff --cached --stat
    echo
    
    print_question "How would you like to create your commit?"
    echo "1) Write commit message now                [git commit -m <message>]"
    echo "2) Open editor for detailed message        [git commit]"
    echo "3) Use conventional commit format          [git commit -m <type>: <desc>]"
    echo "4) View commit message suggestions         [analyze changes]"
    echo "5) Amend previous commit                   [git commit --amend]"
    echo "6) Commit with --verbose (show diff)       [git commit -v]"
    echo "7) Skip commit"
    echo
    read -p "Enter your choice (1-7): " commit_choice
    
    case $commit_choice in
        1)
            read -p "Enter commit message: " commit_msg
            if [[ -n "$commit_msg" ]]; then
                if validate_commit_message "$commit_msg"; then
                    print_command "git commit -m '$commit_msg'"
                    git commit -m "$commit_msg"
                    print_success "Commit created successfully!"
                    log_action "Committed with message: $commit_msg"
                else
                    print_status "Commit cancelled."
                    return 1
                fi
            else
                print_error "Commit message cannot be empty."
                return 1
            fi
            ;;
        2)
            print_command "git commit"
            print_status "Opening editor for commit message..."
            if git commit; then
                print_success "Commit created successfully!"
                log_action "Committed using editor"
            else
                print_warning "Commit was cancelled or failed."
                return 1
            fi
            ;;
        3)
            echo
            print_status "Conventional commit format: <type>[optional scope]: <description>"
            print_status "Types:"
            echo "  feat     - A new feature"
            echo "  fix      - A bug fix"
            echo "  docs     - Documentation only changes"
            echo "  style    - Code style changes (formatting, etc.)"
            echo "  refactor - Code changes that neither fix bugs nor add features"
            echo "  perf     - Performance improvements"
            echo "  test     - Adding missing tests or correcting existing tests"
            echo "  chore    - Build process or auxiliary tool changes"
            echo "  ci       - Continuous integration changes"
            echo "  build    - Build system or dependency changes"
            echo
            read -p "Enter commit type: " commit_type
            read -p "Enter scope (optional, e.g., 'api', 'ui'): " commit_scope
            read -p "Enter description: " commit_desc
            
            if [[ -n "$commit_type" && -n "$commit_desc" ]]; then
                local scope_part=""
                if [[ -n "$commit_scope" ]]; then
                    scope_part="($commit_scope)"
                fi
                local full_message="$commit_type$scope_part: $commit_desc"
                
                print_status "Full commit message: $full_message"
                if validate_commit_message "$full_message"; then
                    print_command "git commit -m '$full_message'"
                    git commit -m "$full_message"
                    print_success "Conventional commit created successfully!"
                    log_action "Committed with conventional format: $full_message"
                else
                    print_status "Commit cancelled."
                    return 1
                fi
            else
                print_error "Both commit type and description are required."
                return 1
            fi
            ;;
        4)
            generate_commit_suggestions
            read -p "Enter suggestion number or type custom message: " suggestion_input
            
            if [[ "$suggestion_input" =~ ^[0-9]+$ ]]; then
                # User selected a suggestion number
                local suggestions=()
                # Regenerate suggestions (simplified)
                suggestions+=("docs: Update documentation" "test: Add/update tests" "chore: Update configuration" "feat: Add new functionality")
                
                if [[ $suggestion_input -ge 1 && $suggestion_input -le ${#suggestions[@]} ]]; then
                    local selected_msg="${suggestions[$((suggestion_input-1))]}"
                    print_command "git commit -m '$selected_msg'"
                    git commit -m "$selected_msg"
                    print_success "Commit created with suggested message!"
                    log_action "Committed with suggestion: $selected_msg"
                else
                    print_error "Invalid suggestion number."
                    return 1
                fi
            elif [[ -n "$suggestion_input" ]]; then
                # User typed custom message
                if validate_commit_message "$suggestion_input"; then
                    print_command "git commit -m '$suggestion_input'"
                    git commit -m "$suggestion_input"
                    print_success "Commit created successfully!"
                    log_action "Committed with custom message: $suggestion_input"
                else
                    print_status "Commit cancelled."
                    return 1
                fi
            else
                print_error "No input provided."
                return 1
            fi
            ;;
        5)
            print_command "git commit --amend"
            print_status "Amending previous commit..."
            if git commit --amend; then
                print_success "Commit amended successfully!"
                log_action "Amended previous commit"
            else
                print_warning "Commit amend was cancelled or failed."
                return 1
            fi
            ;;
        6)
            print_command "git commit -v"
            print_status "Opening commit with verbose mode (shows diff in editor)..."
            if git commit -v; then
                print_success "Verbose commit created successfully!"
                log_action "Committed with verbose mode"
            else
                print_warning "Commit was cancelled or failed."
                return 1
            fi
            ;;
        7)
            print_warning "Skipping commit stage."
            return 1
            ;;
        *)
            print_error "Invalid choice. Skipping commit stage."
            return 1
            ;;
    esac
    
    # Show the created commit
    echo
    print_command "git log --oneline -1"
    print_success "Latest commit: $(git log --oneline -1)"
    
    return 0
}

# Function to check upstream status
check_upstream_status() {
    local current_branch=$1
    
    # Check if we're ahead/behind upstream
    if git rev-parse --abbrev-ref @{upstream} > /dev/null 2>&1; then
        local ahead=$(git rev-list --count @{upstream}..HEAD)
        local behind=$(git rev-list --count HEAD..@{upstream})
        
        if [[ $ahead -gt 0 && $behind -gt 0 ]]; then
            print_warning "Branch is $ahead commits ahead and $behind commits behind upstream"
            print_status "Consider pulling/merging before pushing"
            return 2  # Both ahead and behind
        elif [[ $behind -gt 0 ]]; then
            print_warning "Branch is $behind commits behind upstream"
            print_status "Consider pulling before pushing: git pull"
            return 1  # Behind
        elif [[ $ahead -gt 0 ]]; then
            print_status "Branch is $ahead commits ahead of upstream"
            return 0  # Ahead (good to push)
        else
            print_success "Branch is up to date with upstream"
            return 3  # Up to date
        fi
    else
        print_status "No upstream branch configured"
        return 4  # No upstream
    fi
}

# Function to handle git push
handle_git_push() {
    echo
    print_header "=== GIT PUSH STAGE ==="
    
    local current_branch=$(git branch --show-current)
    print_command "git branch --show-current"
    print_status "Current branch: $current_branch"
    
    # Check remote configuration
    print_command "git remote -v"
    if ! git remote > /dev/null 2>&1; then
        print_error "No remote repositories configured."
        print_status "To add a remote: git remote add origin <url>"
        return 1
    fi
    
    print_status "Available remotes:"
    git remote -v | grep -E '\(push\)$' | while read line; do
        echo "  $line"
    done
    echo
    
    # Check if remote branch exists
    print_command "git ls-remote --exit-code --heads origin '$current_branch'"
    if ! git ls-remote --exit-code --heads origin "$current_branch" > /dev/null 2>&1; then
        print_warning "Remote branch '$current_branch' doesn't exist."
        echo
        print_question "Would you like to push and set upstream? (y/n)"
        read -p "Choice: " setup_upstream
        
        if [[ "$setup_upstream" =~ ^[Yy]$ ]]; then
            print_command "git push -u origin '$current_branch'"
            git push -u origin "$current_branch"
            print_success "Successfully pushed and set upstream!"
            log_action "Set upstream and pushed branch: $current_branch"
        else
            print_warning "Skipping push stage."
            return 1
        fi
        return 0
    fi
    
    # Check upstream status
    check_upstream_status "$current_branch"
    local upstream_status=$?
    
    # Check if there are commits to push
    print_command "git log origin/$current_branch..HEAD"
    if [[ -z $(git log origin/$current_branch..HEAD 2>/dev/null) ]]; then
        if [[ $upstream_status -eq 1 || $upstream_status -eq 2 ]]; then
            print_status "No new commits to push, but upstream has changes."
            read -p "Would you like to pull first? (y/N): " pull_first
            if [[ "$pull_first" =~ ^[Yy]$ ]]; then
                print_command "git pull --rebase"
                git pull --rebase
                # Recursive call after pull
                handle_git_push
                return $?
            fi
        else
            print_warning "No new commits to push."
        fi
        return 1
    fi
    
    echo
    print_status "Commits ready to push:"
    print_command "git log --oneline --graph origin/$current_branch..HEAD"
    git log --oneline --graph origin/$current_branch..HEAD
    echo
    
    # Show push impact
    local commit_count=$(git rev-list --count origin/$current_branch..HEAD)
    local file_count=$(git diff --name-only origin/$current_branch..HEAD | wc -l | tr -d ' ')
    print_status "Push summary: $commit_count commits affecting $file_count files"
    
    print_question "How would you like to push?"
    echo "1) Push to current branch                  [git push]"
    echo "2) Force push (safer)                     [git push --force-with-lease]"
    echo "3) Push with tags                         [git push --follow-tags]"
    echo "4) Push to different branch               [git push origin HEAD:<branch>]"
    echo "5) Push with custom options               [git push <options>]"
    echo "6) Dry run (see what would be pushed)     [git push --dry-run]"
    echo "7) Skip push"
    echo
    read -p "Enter your choice (1-7): " push_choice
    
    case $push_choice in
        1)
            if [[ $upstream_status -eq 1 || $upstream_status -eq 2 ]]; then
                print_warning "Upstream has changes that may conflict!"
                read -p "Continue with push anyway? (y/N): " force_push
                if [[ ! "$force_push" =~ ^[Yy]$ ]]; then
                    print_status "Push cancelled. Consider pulling first."
                    return 1
                fi
            fi
            
            print_command "git push"
            git push
            print_success "Push completed successfully!"
            log_action "Pushed to origin/$current_branch"
            ;;
        2)
            print_warning "Force push can overwrite remote changes!"
            print_status "--force-with-lease is safer as it checks remote hasn't changed"
            read -p "Proceed with force push? (y/n): " confirm_force
            if [[ "$confirm_force" =~ ^[Yy]$ ]]; then
                print_command "git push --force-with-lease"
                git push --force-with-lease
                print_success "Force push completed successfully!"
                log_action "Force pushed to origin/$current_branch"
            else
                print_warning "Force push cancelled."
                return 1
            fi
            ;;
        3)
            print_command "git push --follow-tags"
            print_status "Pushing commits and reachable tags..."
            git push --follow-tags
            print_success "Push with tags completed successfully!"
            log_action "Pushed with tags to origin/$current_branch"
            ;;
        4)
            read -p "Enter target branch name: " target_branch
            if [[ -n "$target_branch" ]]; then
                print_command "git push origin HEAD:'$target_branch'"
                git push origin HEAD:"$target_branch"
                print_success "Pushed to branch '$target_branch' successfully!"
                log_action "Pushed to origin/$target_branch"
            else
                print_error "No target branch specified."
                return 1
            fi
            ;;
        5)
            echo "Available remotes: $(git remote | tr '\n' ' ')"
            read -p "Enter remote name (default: origin): " remote_name
            remote_name=${remote_name:-origin}
            
            read -p "Enter additional push options: " push_options
            local full_command="git push $remote_name $current_branch $push_options"
            
            print_command "$full_command"
            read -p "Execute this command? (y/n): " confirm_custom
            if [[ "$confirm_custom" =~ ^[Yy]$ ]]; then
                eval "$full_command"
                print_success "Custom push completed successfully!"
                log_action "Custom push: $full_command"
            else
                print_warning "Custom push cancelled."
                return 1
            fi
            ;;
        6)
            print_command "git push --dry-run"
            print_status "Showing what would be pushed (dry run):"
            git push --dry-run
            echo
            read -p "Proceed with actual push? (y/N): " proceed_push
            if [[ "$proceed_push" =~ ^[Yy]$ ]]; then
                git push
                print_success "Push completed successfully!"
                log_action "Pushed after dry run to origin/$current_branch"
            else
                print_status "Push cancelled after dry run."
                return 1
            fi
            ;;
        7)
            print_warning "Skipping push stage."
            return 1
            ;;
        *)
            print_error "Invalid choice. Skipping push stage."
            return 1
            ;;
    esac
    
    # Show post-push status
    echo
    print_command "git status -sb"
    print_success "Post-push status:"
    git status -sb
    
    return 0
}

# Function to show help
show_help() {
    cat << EOF
╔══════════════════════════════════════════════════════════════╗
║                Enhanced Interactive Git Workflow             ║
║                        Usage Guide                          ║
╚══════════════════════════════════════════════════════════════╝

USAGE:
    ./enhanced_interactive_git.sh [OPTION]

OPTIONS:
    -h, --help       Show this help message
    -v, --version    Show version information
    -i, --info       Show repository information
    -s, --status     Show detailed repository status
    -l, --log        Show recent workflow log
    --add-only       Run only the add stage
    --commit-only    Run only the commit stage (requires staged files)
    --push-only      Run only the push stage (requires commits to push)
    --quick          Quick workflow (add all, commit with message, push)

FEATURES:
    ● Interactive file staging with previews
    ● Patch-mode adding for granular control  [git add -p]
    ● Smart commit message suggestions
    ● Conventional commit format support
    ● Commit message validation
    ● Advanced push options with upstream checking
    ● Force push with --force-with-lease safety
    ● Dry run capabilities
    ● Comprehensive logging of all actions
    ● Repository status and branch information

GIT COMMANDS SHOWN:
    All git commands are displayed in [COMMAND] format before execution.
    This helps you learn the underlying git operations while using the tool.

EXAMPLES:
    ./enhanced_interactive_git.sh              # Full interactive workflow
    ./enhanced_interactive_git.sh --quick      # Quick add/commit/push
    ./enhanced_interactive_git.sh --status     # Show detailed status
    ./enhanced_interactive_git.sh --add-only   # Only run add stage
    ./enhanced_interactive_git.sh --info       # Show repo information

LOGS:
    Workflow actions are logged to: $GIT_LOG_DIR/git_workflow.log

EOF
}

# Function to show version
show_version() {
    echo "Enhanced Interactive Git Workflow v2.0"
    echo "Created for comprehensive git operations with detailed explanations"
    echo "Built with ❤️  for efficient git workflows"
}

# Function to show recent log
show_recent_log() {
    local log_file="$GIT_LOG_DIR/git_workflow.log"
    if [[ -f "$log_file" ]]; then
        print_header "=== RECENT WORKFLOW LOG ==="
        print_command "tail -20 '$log_file'"
        tail -20 "$log_file" | while read -r line; do
            echo "  $line"
        done
    else
        print_warning "No workflow log found at $log_file"
    fi
}

# Function for quick workflow
quick_workflow() {
    print_header "=== QUICK WORKFLOW ==="
    print_status "Running automated add, commit, and push..."
    
    # Check git repo
    check_git_repo
    
    # Quick add all
    if [[ -n $(git status --porcelain) ]]; then
        print_command "git add ."
        git add .
        print_success "All changes added!"
        log_action "Quick workflow: Added all changes"
    else
        print_warning "No changes to add."
        return 1
    fi
    
    # Quick commit
    if [[ -n $(git diff --cached --name-only) ]]; then
        read -p "Enter commit message: " quick_msg
        if [[ -n "$quick_msg" ]]; then
            print_command "git commit -m '$quick_msg'"
            git commit -m "$quick_msg"
            print_success "Commit created!"
            log_action "Quick workflow: Committed with message: $quick_msg"
        else
            print_error "Commit message required for quick workflow."
            return 1
        fi
    else
        print_warning "No staged changes to commit."
        return 1
    fi
    
    # Quick push
    local current_branch=$(git branch --show-current)
    if git ls-remote --exit-code --heads origin "$current_branch" > /dev/null 2>&1; then
        if [[ -n $(git log origin/$current_branch..HEAD 2>/dev/null) ]]; then
            print_command "git push"
            git push
            print_success "Push completed!"
            log_action "Quick workflow: Pushed to origin/$current_branch"
        else
            print_warning "No new commits to push."
        fi
    else
        read -p "Set upstream and push? (y/N): " set_upstream
        if [[ "$set_upstream" =~ ^[Yy]$ ]]; then
            print_command "git push -u origin '$current_branch'"
            git push -u origin "$current_branch"
            print_success "Upstream set and pushed!"
            log_action "Quick workflow: Set upstream and pushed $current_branch"
        fi
    fi
    
    print_success "Quick workflow completed!"
}

# Main function
main() {
    # Handle command line arguments
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        -i|--info)
            check_git_repo
            show_repo_info
            exit 0
            ;;
        -s|--status)
            check_git_repo
            show_status
            exit 0
            ;;
        -l|--log)
            show_recent_log
            exit 0
            ;;
        --add-only)
            check_git_repo
            handle_git_add
            exit $?
            ;;
        --commit-only)
            check_git_repo
            handle_git_commit
            exit $?
            ;;
        --push-only)
            check_git_repo
            handle_git_push
            exit $?
            ;;
        --quick)
            quick_workflow
            exit $?
            ;;
        "")
            # No arguments - run full interactive workflow
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
    
    # Full interactive workflow
    echo
    echo "╔══════════════════════════════════════════════╗"
    echo "║     Enhanced Interactive Git Workflow        ║"
    echo "║            [git commands shown]              ║"
    echo "╚══════════════════════════════════════════════╝"
    echo
    
    log_action "Started full interactive workflow"
    
    # Check if we're in a git repository
    check_git_repo
    
    # Show initial status
    show_status
    
    # Process stages
    add_success=false
    commit_success=false
    
    # Git Add Stage
    if handle_git_add; then
        add_success=true
    fi
    
    # Git Commit Stage (only if add was successful)
    if $add_success; then
        if handle_git_commit; then
            commit_success=true
        fi
    fi
    
    # Git Push Stage (only if commit was successful)
    if $commit_success; then
        handle_git_push
    fi
    
    echo
    print_header "=== WORKFLOW COMPLETE ==="
    show_status
    echo
    print_success "Thank you for using Enhanced Interactive Git Workflow!"
    print_status "View logs with: $0 --log"
    print_status "Get help with: $0 --help"
    
    log_action "Completed full interactive workflow"
}

# Run main function
main "$@"
