import os
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

def set_cell_background(cell, fill_hex):
    shading_elm = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    cell._tc.get_or_add_tcPr().append(shading_elm)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = OxmlElement('w:tcMar')
    for m, val in [('top', top), ('bottom', bottom), ('left', left), ('right', right)]:
        node = OxmlElement(f'w:{m}')
        node.set(qn('w:w'), str(val))
        node.set(qn('w:type'), 'dxa')
        tcMar.append(node)
    tcPr.append(tcMar)

def set_table_borders(table, color="D3D3D3", sz="4", val="single"):
    tblPr = table._tbl.tblPr
    borders = parse_xml(
        f'<w:tblBorders {nsdecls("w")}>\n'
        f'  <w:top w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>\n'
        f'  <w:bottom w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>\n'
        f'  <w:left w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>\n'
        f'  <w:right w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>\n'
        f'  <w:insideH w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>\n'
        f'  <w:insideV w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>\n'
        f'</w:tblBorders>'
    )
    tblPr.append(borders)

def build_document():
    doc = Document()

    # Set standard 1-inch margins
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)

    # Style definitions
    normal_style = doc.styles['Normal']
    normal_style.font.name = 'Calibri'
    normal_style.font.size = Pt(11)
    normal_style.font.color.rgb = RGBColor(33, 37, 41)
    normal_style.paragraph_format.line_spacing = 1.15
    normal_style.paragraph_format.space_after = Pt(6)

    # Helper functions
    def add_title(text):
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(12)
        run = p.add_run(text)
        run.bold = True
        run.font.size = Pt(18)
        run.font.color.rgb = RGBColor(26, 35, 126) # Deep Navy
        return p

    def add_subtitle(text):
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_after = Pt(8)
        run = p.add_run(text)
        run.font.size = Pt(12)
        run.font.color.rgb = RGBColor(70, 70, 70)
        return p

    def add_heading1(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(16)
        p.paragraph_format.space_after = Pt(6)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        run.bold = True
        run.font.size = Pt(15)
        run.font.color.rgb = RGBColor(26, 35, 126) # Deep Navy
        return p

    def add_heading2(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(12)
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        run.bold = True
        run.font.size = Pt(13)
        run.font.color.rgb = RGBColor(40, 53, 147)
        return p

    def add_heading3(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(8)
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        run.bold = True
        run.font.size = Pt(11.5)
        run.font.color.rgb = RGBColor(55, 71, 79)
        return p

    def add_body(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(6)
        p.paragraph_format.line_spacing = 1.15
        p.add_run(text)
        return p

    def add_bullet(text, bold_prefix=None):
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.line_spacing = 1.15
        if bold_prefix:
            r1 = p.add_run(bold_prefix)
            r1.bold = True
        p.add_run(text)
        return p

    # -------------------------------------------------------------
    # 1. COVER PAGE / TITLE PAGE
    # -------------------------------------------------------------
    p_inst = doc.add_paragraph()
    p_inst.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_inst = p_inst.add_run("BANSILAL RAMNATH AGARWAL CHARITABLE TRUST'S\n")
    r_inst.bold = True
    r_inst.font.size = Pt(11)
    r_vit = p_inst.add_run("VISHWAKARMA INSTITUTE OF TECHNOLOGY, PUNE – 411037\n")
    r_vit.bold = True
    r_vit.font.size = Pt(13)
    r_vit.font.color.rgb = RGBColor(26, 35, 126)
    r_aut = p_inst.add_run("(An Autonomous Institute Affiliated to Savitribai Phule Pune University)\nDEPARTMENT OF COMPUTER SCIENCE AND ENGINEERING (ARTIFICIAL INTELLIGENCE)")
    r_aut.font.size = Pt(9.5)
    r_aut.italic = True

    doc.add_paragraph().paragraph_format.space_after = Pt(18)

    p_proj = doc.add_paragraph()
    p_proj.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_subm = p_proj.add_run("A COURSE PROJECT REPORT ON\n\n")
    r_subm.font.size = Pt(11)
    r_subm.bold = True
    r_title = p_proj.add_run("“EQUILIBRIUM: AUTONOMOUS STUDENT WORKLOAD BALANCER & AI-POWERED ACADEMIC SCHEDULING PLATFORM”\n")
    r_title.bold = True
    r_title.font.size = Pt(16)
    r_title.font.color.rgb = RGBColor(26, 35, 126)

    doc.add_paragraph().paragraph_format.space_after = Pt(10)

    p_course = doc.add_paragraph()
    p_course.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_c1 = p_course.add_run("SUBMITTED IN PARTIAL FULFILLMENT OF THE REQUIREMENTS FOR THE DEGREE OF\n")
    r_c1.font.size = Pt(10)
    r_c2 = p_course.add_run("BACHELOR OF TECHNOLOGY\nIN\nCOMPUTER SCIENCE AND ENGINEERING (ARTIFICIAL INTELLIGENCE)\n\n")
    r_c2.bold = True
    r_c2.font.size = Pt(11)
    r_c3 = p_course.add_run("COURSE: DESIGN THINKING & PRODUCT LIFECYCLE MANAGEMENT (DTPLM)\nACADEMIC YEAR: 2026 – 2027 (SEM I)")
    r_c3.bold = True
    r_c3.font.size = Pt(11)
    r_c3.font.color.rgb = RGBColor(183, 28, 28)

    doc.add_paragraph().paragraph_format.space_after = Pt(16)

    # Table of Project Contributors
    p_sub = doc.add_paragraph()
    p_sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_sb = p_sub.add_run("SUBMITTED BY GROUP – 2:")
    r_sb.bold = True
    r_sb.font.size = Pt(11)

    table_students = doc.add_table(rows=5, cols=4)
    table_students.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(table_students)

    headers = ["Roll No.", "G.R. No.", "Name of Student", "Email ID"]
    for i, h in enumerate(headers):
        cell = table_students.cell(0, i)
        cell.text = h
        set_cell_background(cell, "E8EAF6")
        set_cell_margins(cell, 120, 120, 150, 150)
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.runs[0].font.bold = True
        p.runs[0].font.size = Pt(9.5)

    students_data = [
        ("08", "12414729", "Janhavi Prashant Nalse", "janhavi.nalse24@vit.edu"),
        ("09", "12414885", "Sai Amol Jannawar", "sai.jannawar24@vit.edu"),
        ("12", "12412865", "Aayush Jha", "aayush.jha24@vit.edu"),
        ("24", "12411747", "Shreeyash Satish Kamble", "shreeyash.kamble24@vit.edu")
    ]

    for row_idx, data in enumerate(students_data, start=1):
        for col_idx, text in enumerate(data):
            cell = table_students.cell(row_idx, col_idx)
            cell.text = text
            set_cell_margins(cell, 100, 100, 150, 150)
            p = cell.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER if col_idx < 2 else WD_ALIGN_PARAGRAPH.LEFT
            p.runs[0].font.size = Pt(9.5)

    doc.add_paragraph().paragraph_format.space_after = Pt(20)

    p_guide = doc.add_paragraph()
    p_guide.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_g1 = p_guide.add_run("UNDER THE VALUED GUIDANCE OF\n")
    r_g1.font.size = Pt(10)
    r_g2 = p_guide.add_run("Dr. Nilesh B. Korade\n")
    r_g2.bold = True
    r_g2.font.size = Pt(12)
    r_g3 = p_guide.add_run("Department of Computer Science and Engineering (Artificial Intelligence)\nVishwakarma Institute of Technology, Pune – 411037")
    r_g3.font.size = Pt(10)

    doc.add_page_break()

    # -------------------------------------------------------------
    # 2. CERTIFICATE OF APPROVAL
    # -------------------------------------------------------------
    p_cert_inst = doc.add_paragraph()
    p_cert_inst.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_c_inst = p_cert_inst.add_run("BANSILAL RAMNATH AGARWAL CHARITABLE TRUST'S\n")
    r_c_inst.bold = True
    r_c_inst.font.size = Pt(11)
    r_c_vit = p_cert_inst.add_run("VISHWAKARMA INSTITUTE OF TECHNOLOGY, PUNE – 411037\n")
    r_c_vit.bold = True
    r_c_vit.font.size = Pt(13)
    r_c_vit.font.color.rgb = RGBColor(26, 35, 126)
    r_c_aut = p_cert_inst.add_run("(An Autonomous Institute Affiliated to Savitribai Phule Pune University)\nDEPARTMENT OF COMPUTER SCIENCE AND ENGINEERING (ARTIFICIAL INTELLIGENCE)")
    r_c_aut.font.size = Pt(9.5)
    r_c_aut.italic = True

    doc.add_paragraph().paragraph_format.space_after = Pt(16)

    add_title("CERTIFICATE")

    p_cert_body = doc.add_paragraph()
    p_cert_body.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p_cert_body.paragraph_format.line_spacing = 1.3
    p_cert_body.paragraph_format.space_after = Pt(14)
    r_cb = p_cert_body.add_run(
        "This is to certify that the Course Project Report entitled "
        "“Equilibrium: Autonomous Student Workload Balancer & AI-Powered Academic Scheduling Platform” "
        "submitted by Janhavi Prashant Nalse (12414729), Sai Amol Jannawar (12414885), Aayush Jha (12412865), "
        "and Shreeyash Satish Kamble (12411747) of Group – 2 is a bona fide record of work carried out by them "
        "in partial fulfillment for the award of the Degree of Bachelor of Technology in Computer Science and "
        "Engineering (Artificial Intelligence) of Vishwakarma Institute of Technology, affiliated to Savitribai "
        "Phule Pune University, during the Academic Year 2026 – 2027, Semester – I."
    )
    r_cb.font.size = Pt(11)

    p_cert_body2 = doc.add_paragraph()
    p_cert_body2.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p_cert_body2.paragraph_format.line_spacing = 1.3
    r_cb2 = p_cert_body2.add_run(
        "The project has been completed under our direct supervision and guidance, satisfying all the academic "
        "and technical requirements stipulated by the Institute curriculum for Design Thinking & Product "
        "Lifecycle Management (DTPLM)."
    )
    r_cb2.font.size = Pt(11)

    doc.add_paragraph().paragraph_format.space_after = Pt(60)

    # Signatures Table
    table_sig = doc.add_table(rows=2, cols=2)
    table_sig.alignment = WD_TABLE_ALIGNMENT.CENTER
    cell_g = table_sig.cell(0, 0)
    cell_h = table_sig.cell(0, 1)

    p_g = cell_g.paragraphs[0]
    p_g.alignment = WD_ALIGN_PARAGRAPH.LEFT
    r_g = p_g.add_run("_______________________________\nDr. Nilesh B. Korade\nProject Internal Guide\nDepartment of CSE(AI)\nVIT, Pune")
    r_g.bold = True
    r_g.font.size = Pt(10.5)

    p_h = cell_h.paragraphs[0]
    p_h.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    r_h = p_h.add_run("_______________________________\nProf. Dr. Nilesh P. Sable\nHead of Department (HOD)\nDepartment of CSE(AI)\nVIT, Pune")
    r_h.bold = True
    r_h.font.size = Pt(10.5)

    cell_dt1 = table_sig.cell(1, 0)
    cell_dt2 = table_sig.cell(1, 1)
    p_dt = cell_dt1.paragraphs[0]
    p_dt.paragraph_format.space_before = Pt(25)
    r_dt = p_dt.add_run("Place: VIT, Pune\nDate: 26-10-2026")
    r_dt.font.size = Pt(10)

    doc.add_page_break()

    # -------------------------------------------------------------
    # 3. DECLARATION & ACKNOWLEDGEMENT
    # -------------------------------------------------------------
    add_title("DECLARATION")
    p_dec = doc.add_paragraph()
    p_dec.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p_dec.paragraph_format.line_spacing = 1.25
    r_dec = p_dec.add_run(
        "We hereby declare that the course project report entitled “Equilibrium: Autonomous Student Workload "
        "Balancer & AI-Powered Academic Scheduling Platform” is an authentic record of our own research and "
        "development work conducted at Vishwakarma Institute of Technology, Pune. Any external libraries, "
        "algorithms, documentation, or frameworks integrated into this project have been fully credited and "
        "cited in accordance with standard academic integrity guidelines. This work has not been previously "
        "submitted for the award of any other degree or diploma to this or any other university."
    )
    r_dec.font.size = Pt(11)

    doc.add_paragraph().paragraph_format.space_after = Pt(20)

    # Student signature lines
    table_dec = doc.add_table(rows=2, cols=2)
    table_dec.alignment = WD_TABLE_ALIGNMENT.CENTER
    dec_names = [
        "Janhavi Prashant Nalse (12414729)",
        "Sai Amol Jannawar (12414885)",
        "Aayush Jha (12412865)",
        "Shreeyash Satish Kamble (12411747)"
    ]
    for idx, name in enumerate(dec_names):
        r_idx = idx // 2
        c_idx = idx % 2
        c = table_dec.cell(r_idx, c_idx)
        p = c.paragraphs[0]
        p.paragraph_format.space_before = Pt(14)
        p.add_run(f"___________________________\n{name}\n")

    doc.add_paragraph().paragraph_format.space_after = Pt(24)

    add_title("ACKNOWLEDGEMENT")
    p_ack = doc.add_paragraph()
    p_ack.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p_ack.paragraph_format.line_spacing = 1.25
    r_ack = p_ack.add_run(
        "We wish to express our profound gratitude and heartfelt thanks to our project guide, Dr. Nilesh B. Korade, "
        "Department of Computer Science and Engineering (Artificial Intelligence), for his insightful suggestions, "
        "invaluable guidance, constructive criticism, and continuous mentorship throughout the ideation, mathematical "
        "formulation, and full-stack deployment of the Equilibrium platform.\n\n"
        "We extend our sincere thanks to Prof. Dr. Nilesh P. Sable, Head of the Department of Computer Science "
        "and Engineering (AI), for his visionary leadership, continuous encouragement, and for providing a highly "
        "stimulating academic environment that fostered innovative technological development.\n\n"
        "We also convey our gratitude to the Director and the Management of Vishwakarma Institute of Technology, "
        "Pune, for providing the necessary infrastructural resources, high-speed computational facilities, and cloud "
        "environments essential for executing our continuous integration pipelines and automated testing harnesses.\n\n"
        "Finally, we are grateful to our families, peers, and fellow classmates whose unwavering moral support, feedback, "
        "and patience sustained us through every phase of this project lifecycle."
    )
    r_ack.font.size = Pt(11)

    doc.add_page_break()

    # -------------------------------------------------------------
    # 4. PART I: PROJECT SYNOPSIS
    # -------------------------------------------------------------
    p_syn_h = doc.add_paragraph()
    p_syn_h.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_sh1 = p_syn_h.add_run("BANSILAL RAMNATH AGARWAL CHARITABLE TRUST'S\n")
    r_sh1.bold = True
    r_sh1.font.size = Pt(11)
    r_sh2 = p_syn_h.add_run("VISHWAKARMA INSTITUTE OF TECHNOLOGY, PUNE – 411037\n")
    r_sh2.bold = True
    r_sh2.font.size = Pt(13)
    r_sh2.font.color.rgb = RGBColor(26, 35, 126)
    r_sh3 = p_syn_h.add_run("DEPARTMENT OF COMPUTER SCIENCE AND ENGINEERING (ARTIFICIAL INTELLIGENCE)\n")
    r_sh3.font.size = Pt(10)
    r_sh3.bold = True
    r_sh4 = p_syn_h.add_run("PROJECT SYNOPSIS")
    r_sh4.bold = True
    r_sh4.font.size = Pt(14)
    r_sh4.font.color.rgb = RGBColor(183, 28, 28)

    doc.add_paragraph().paragraph_format.space_after = Pt(8)

    # Synopsis Info Table
    table_syn = doc.add_table(rows=6, cols=5)
    table_syn.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(table_syn)

    syn_headers = ["Roll No.", "G.R. No.", "Name of Student", "Contact No.", "Email ID"]
    for i, h in enumerate(syn_headers):
        cell = table_syn.cell(0, i)
        cell.text = h
        set_cell_background(cell, "E8EAF6")
        set_cell_margins(cell, 100, 100, 120, 120)
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.runs[0].font.bold = True
        p.runs[0].font.size = Pt(9)

    syn_data = [
        ("08", "12414729", "Janhavi Prashant Nalse", "8552071320", "janhavi.nalse24@vit.edu"),
        ("09", "12414885", "Sai Amol Jannawar", "8767171613", "sai.jannawar24@vit.edu"),
        ("12", "12412865", "Aayush Jha", "8626066020", "aayush.jha24@vit.edu"),
        ("24", "12411747", "Shreeyash Satish Kamble", "8308483178", "shreeyash.kamble24@vit.edu"),
    ]

    for row_idx, row_items in enumerate(syn_data, start=1):
        for col_idx, item in enumerate(row_items):
            cell = table_syn.cell(row_idx, col_idx)
            cell.text = item
            set_cell_margins(cell, 80, 80, 100, 100)
            p = cell.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER if col_idx in [0, 1, 3] else WD_ALIGN_PARAGRAPH.LEFT
            p.runs[0].font.size = Pt(8.5)

    # Metadata row
    c_meta = table_syn.cell(5, 0)
    c_meta.merge(table_syn.cell(5, 4))
    set_cell_background(c_meta, "FAFAFA")
    set_cell_margins(c_meta, 80, 80, 120, 120)
    p_meta = c_meta.paragraphs[0]
    p_meta.paragraph_format.line_spacing = 1.15
    p_meta.add_run("Group No: ").bold = True
    p_meta.add_run("2  |  ")
    p_meta.add_run("Academic Year: ").bold = True
    p_meta.add_run("2026 – 2027 (SEM I)  |  ")
    p_meta.add_run("Course: ").bold = True
    p_meta.add_run("DTPLM  |  ")
    p_meta.add_run("Guide: ").bold = True
    p_meta.add_run("Dr. Nilesh B. Korade")
    p_meta.runs[0].font.size = Pt(9)

    doc.add_paragraph().paragraph_format.space_after = Pt(10)

    # Synopsis Fields
    def add_syn_field(title, content):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(6)
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.line_spacing = 1.15
        r_t = p.add_run(f"{title}: ")
        r_t.bold = True
        r_t.font.color.rgb = RGBColor(26, 35, 126)
        p.add_run(content)

    add_syn_field("Project Title", "Equilibrium: Autonomous Student Workload Balancer & AI-Powered Academic Scheduling Platform.")
    add_syn_field("Project Domain / Area", "Autonomous Optimization Systems, Design Thinking, Full-Stack Distributed Systems, Cloud Architecture, Human-Centered AI.")
    add_syn_field("Problem Statement", 
        "Undergraduate engineering students face severe academic burnout and chronic sleep deprivation caused by multi-deadline "
        "workloads, uncoordinated assignments, lab reports, exams, and fixed academic schedules. Traditional productivity tools "
        "(Google Calendar, Notion, Todoist) act as passive to-do lists that require tedious manual time-blocking and fail to account "
        "for human physiological constraints. When workloads exceed physical daylight capacity, students invariably sacrifice sleep, "
        "triggering severe cognitive fatigue, substandard academic performance, and acute mental health distress."
    )

    add_syn_field("Project Objectives",
        "\n1. To enforce a non-negotiable, mathematically guaranteed 'Sleep Shield' (minimum 7.0 hours/night) that rejects any task scheduling within biological rest windows."
        "\n2. To formulate and implement a multi-objective 0/1 Knapsack optimization algorithm that maximizes high-value academic throughput without exceeding cognitive capacity."
        "\n3. To construct an energy-aware heuristic placement engine that maps high-cognitive-load study tasks to students' verified circadian peak energy intervals."
        "\n4. To deliver an anti-fragile conversational rescheduling engine backed by Groq Cloud LLM (OpenAI-compatible) and deterministic fallback parsing."
        "\n5. To engineer a secure, enterprise-grade authentication system featuring 6-digit email OTP verification via Resend and HMAC-SHA256 digests."
        "\n6. To deploy a cross-platform Flutter Android mobile application and automated continuous integration pipeline with physical cloud production infrastructure."
    )

    add_syn_field("Methodology & System Architecture",
        "The proposed platform is engineered using a decoupled, reactive 3-tier client-server architecture:\n"
        "• Mobile Client (Flutter/Dart): Provides an intuitive, responsive mobile experience featuring a real-time 'Today' dynamic timeline, quick-add floating action center, focus timer, conversational rescheduling dialog, and workload analytics charts.\n"
        "• Backend REST API (Node.js/Express/TypeScript): Implements mathematically verified scheduling services, Prisma ORM data modeling, rate limiting, and Groq LLM integration.\n"
        "• Persistence Layer (PostgreSQL on Supabase): High-performance relational storage enforcing referential integrity, cascading deletes, and advisory transaction locks.\n"
        "• Mathematical Core: Operates in three sequential deterministic phases: (A) Dynamic Programming Knapsack Task Selection, (B) Energy-Aware Placement & Task Splitting, and (C) Mathematical Schedule Validation (`validator.ts`)."
    )

    add_syn_field("Hardware & Software Requirements",
        "• Hardware: Minimum 8GB RAM, Quad-Core x64/ARM64 processor, 10GB free disk space, Android 8.0+ mobile device.\n"
        "• Software: Node.js 20 LTS, Flutter SDK 3.x, Android SDK 34, PostgreSQL 16 (Supabase), VS Code, Git, GitHub Actions."
    )

    add_syn_field("Expected Deliverables & Impact",
        "A production-ready Android APK (v1.1.2) signed with a persistent release keystore, a live deployed cloud backend on Render, "
        "an automated GitHub Actions CI/CD release pipeline, and verified elimination of sleep-encroaching study allocations."
    )

    doc.add_page_break()

    # -------------------------------------------------------------
    # 5. ABSTRACT & TABLE OF CONTENTS
    # -------------------------------------------------------------
    add_title("ABSTRACT")
    p_abs = doc.add_paragraph()
    p_abs.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p_abs.paragraph_format.line_spacing = 1.25
    r_abs = p_abs.add_run(
        "Academic burnout among engineering undergraduates has reached crisis proportions due to conflicting multi-deadline "
        "commitments, intensive coursework, and static time-management tools that merely log deadlines rather than resolving scheduling "
        "conflicts. Traditional calendars and to-do list applications operate on passive recording paradigms, shifting the entire "
        "cognitive burden of schedule synthesis onto already exhausted students. Inevitably, when workload exceeds daylight hours, "
        "students compromise sleep, resulting in cumulative sleep debt, impaired cognitive retention, and burnout.\n\n"
        "This project presents Equilibrium, an autonomous, full-stack student workload balancer and academic scheduling ecosystem "
        "designed under the Design Thinking and Product Lifecycle Management (DTPLM) framework. Equilibrium redefines time management "
        "by shifting from passive tracking to autonomous constraint optimization. At the core of Equilibrium lies a novel, three-phase "
        "mathematical scheduling engine: (1) a multi-objective 0/1 Knapsack Dynamic Programming task selector that scores tasks "
        "based on academic weight, urgency, team impact, and deferral debt; (2) an Energy-Aware heuristic placement algorithm that "
        "discretizes days into 30-minute blocks and aligns high-cognitive tasks with biological peak energy windows; and (3) an inviolable "
        "Sleep Shield validator that mathematically enforces a minimum 7.0-hour biological rest window, automatically deferring lower-priority "
        "tasks with clear causal explanations when overload occurs.\n\n"
        "The platform incorporates an intelligent conversational rescheduling engine powered by the Groq Cloud LLM API with deterministic "
        "fallback parsing, a secure cryptographic authentication service utilizing 6-digit email OTPs delivered via Resend, and a "
        "streamlined Flutter Android mobile application. Verified through 435 automated test specifications across 7 distinct testing layers, "
        "Equilibrium achieves 100% adherence to hard constraints, sub-150ms schedule generation latency, and provides a sustainable, "
        "scientifically grounded paradigm for student wellbeing."
    )
    r_abs.font.size = Pt(10.5)

    doc.add_paragraph().paragraph_format.space_after = Pt(14)

    # TABLE OF CONTENTS
    add_title("TABLE OF CONTENTS")
    
    table_toc = doc.add_table(rows=1, cols=3)
    table_toc.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(table_toc)
    
    toc_head = table_toc.rows[0]
    toc_head.cells[0].text = "Chapter / Section"
    toc_head.cells[1].text = "Title"
    toc_head.cells[2].text = "Page No."
    set_cell_background(toc_head.cells[0], "E8EAF6")
    set_cell_background(toc_head.cells[1], "E8EAF6")
    set_cell_background(toc_head.cells[2], "E8EAF6")
    for c in toc_head.cells:
        c.paragraphs[0].runs[0].font.bold = True
        c.paragraphs[0].runs[0].font.size = Pt(9.5)
        set_cell_margins(c, 80, 80, 100, 100)

    toc_items = [
        ("", "Certificate of Approval", "ii"),
        ("", "Declaration & Acknowledgement", "iii"),
        ("", "Project Synopsis", "iv"),
        ("", "Abstract", "v"),
        ("", "List of Figures & List of Tables", "vi"),
        ("CHAPTER 1", "INTRODUCTION", "1"),
        ("1.1", "Overview of the Project & Product Vision", "1"),
        ("1.2", "Problem Statement & Real-World Student Dilemma", "2"),
        ("1.3", "Design Thinking & Product Lifecycle Management (DTPLM) Framework", "3"),
        ("1.4", "Objectives of the Project", "4"),
        ("1.5", "Scope and Key Boundaries of the Platform", "5"),
        ("CHAPTER 2", "LITERATURE SURVEY & SYSTEM BENCHMARKING", "6"),
        ("2.1", "Analysis of Existing Productivity & Time-Management Systems", "6"),
        ("2.2", "Limitations of Current Paradigms", "7"),
        ("2.3", "Proposed Equilibrium Architectural Paradigm", "8"),
        ("2.4", "Comprehensive Feature-by-Feature Comparative Matrix", "9"),
        ("CHAPTER 3", "SYSTEM ANALYSIS AND ARCHITECTURE DESIGN", "10"),
        ("3.1", "System Requirements (Hardware, Software, Cloud & Network)", "10"),
        ("3.2", "High-Level Distributed System Architecture", "11"),
        ("3.3", "The Mathematical Core: Multi-Phase Scheduling Engine", "13"),
        ("3.3.1", "30-Minute Discretization & Formal Problem Formulation", "13"),
        ("3.3.2", "Hard Constraints vs. Soft Cognitive Preferences", "14"),
        ("3.3.3", "Multi-Objective Priority Scoring Formula (α, β, γ, δ)", "15"),
        ("3.3.4", "Phase A: 0/1 Knapsack Dynamic Programming Task Selector", "16"),
        ("3.3.5", "Phase B: Energy-Aware Placement & Bounded Task Splitting", "17"),
        ("3.3.6", "Phase C: Schedule Validation Engine (validator.ts)", "18"),
        ("3.4", "Actors, Use Cases & Interaction Modeling", "19"),
        ("3.5", "Relational Database Schema & Entity-Relationship Modeling", "20"),
        ("3.6", "Modular Subsystem & Micro-Service Architecture", "22"),
        ("CHAPTER 4", "IMPLEMENTATION, TESTING AND VERIFICATION", "24"),
        ("4.1", "Experimental Setup & Technology Stack Details", "24"),
        ("4.2", "Autonomous Algorithmic Scheduling Logic & Rescheduling Flowchart", "25"),
        ("4.3", "Mobile Application Screen Workflows & User Interface Architecture", "27"),
        ("4.4", "Comprehensive Test Suite, Test Cases, and Results", "30"),
        ("4.5", "Performance, Latency, and Computational Complexity Analysis", "34"),
        ("CHAPTER 5", "CONCLUSION AND FUTURE SCOPE", "36"),
        ("5.1", "Conclusion & Accomplished Milestones", "36"),
        ("5.2", "Future Roadmap & Technical Enhancements", "37"),
        ("", "REFERENCES", "38")
    ]

    for item in toc_items:
        row = table_toc.add_row()
        row.cells[0].text = item[0]
        row.cells[1].text = item[1]
        row.cells[2].text = item[2]
        set_cell_margins(row.cells[0], 60, 60, 80, 80)
        set_cell_margins(row.cells[1], 60, 60, 80, 80)
        set_cell_margins(row.cells[2], 60, 60, 80, 80)
        for i, c in enumerate(row.cells):
            p = c.paragraphs[0]
            if item[0].startswith("CHAPTER") or item[1] in ["REFERENCES", "Project Synopsis", "Abstract"]:
                p.runs[0].font.bold = True
            p.runs[0].font.size = Pt(8.5)
            if i == 2:
                p.alignment = WD_ALIGN_PARAGRAPH.RIGHT

    doc.add_page_break()

    # LIST OF FIGURES & LIST OF TABLES
    add_title("LIST OF FIGURES & LIST OF TABLES")
    
    add_heading2("LIST OF FIGURES")
    figures = [
        ("Figure 1.1", "Design Thinking Empathy Map & Double Diamond Lifecycle in Equilibrium", "3"),
        ("Figure 1.2", "North Star Metric (NSM) Hierarchical Metric Tree", "4"),
        ("Figure 3.1", "High-Level Distributed System Architecture (Client-Server-Cloud)", "12"),
        ("Figure 3.2", "The 30-Minute Time Slot Matrix & Sleep Shield Boundary", "14"),
        ("Figure 3.3", "Multi-Phase Autonomous Scheduling Engine Execution Pipeline", "18"),
        ("Figure 3.4", "Use Case Diagram for Student, Academic Collaborator, and Auto-Scheduler", "19"),
        ("Figure 3.5", "Relational Entity-Relationship (ER) Schema Diagram", "21"),
        ("Figure 4.1", "Autonomous Algorithmic Scheduling Logic & Rescheduling Flowchart", "26"),
        ("Figure 4.2", "Mobile Client Screens: Onboarding, OTP Verification, and Today Timeline", "28"),
        ("Figure 4.3", "Mobile Client Screens: Focus Timer, Rescheduling Chat, and Workload Analytics", "29"),
        ("Figure 4.4", "Automated GitHub Actions CI/CD Release Pipeline", "33")
    ]

    table_fig = doc.add_table(rows=1, cols=3)
    table_fig.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(table_fig)
    tf_h = table_fig.rows[0]
    tf_h.cells[0].text = "Figure No."
    tf_h.cells[1].text = "Caption / Description"
    tf_h.cells[2].text = "Page No."
    set_cell_background(tf_h.cells[0], "E8EAF6")
    set_cell_background(tf_h.cells[1], "E8EAF6")
    set_cell_background(tf_h.cells[2], "E8EAF6")
    for c in tf_h.cells:
        c.paragraphs[0].runs[0].font.bold = True
        c.paragraphs[0].runs[0].font.size = Pt(9)
        set_cell_margins(c, 60, 60, 80, 80)

    for f in figures:
        row = table_fig.add_row()
        row.cells[0].text = f[0]
        row.cells[1].text = f[1]
        row.cells[2].text = f[2]
        set_cell_margins(row.cells[0], 50, 50, 80, 80)
        set_cell_margins(row.cells[1], 50, 50, 80, 80)
        set_cell_margins(row.cells[2], 50, 50, 80, 80)
        for i, c in enumerate(row.cells):
            p = c.paragraphs[0]
            p.runs[0].font.size = Pt(8.5)
            if i == 2:
                p.alignment = WD_ALIGN_PARAGRAPH.RIGHT

    doc.add_paragraph().paragraph_format.space_after = Pt(14)

    add_heading2("LIST OF TABLES")
    tables_list = [
        ("Table 2.1", "State-of-the-Art Benchmarking: Traditional Calendars vs. Equilibrium", "9"),
        ("Table 3.1", "Hardware and Software Specification Matrix", "10"),
        ("Table 3.2", "System Constraints: Hard Inviolable vs. Soft Optimization Preferences", "15"),
        ("Table 3.3", "Database Relational Entities, Primary Keys, and Cardinality", "22"),
        ("Table 4.1", "Enterprise Technology Stack Blueprint", "24"),
        ("Table 4.2", "Comprehensive System Test Verification Matrix (15 Detailed Test Cases)", "31"),
        ("Table 4.3", "Algorithmic Time and Space Complexity Benchmarks", "35")
    ]

    table_tbl = doc.add_table(rows=1, cols=3)
    table_tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(table_tbl)
    tt_h = table_tbl.rows[0]
    tt_h.cells[0].text = "Table No."
    tt_h.cells[1].text = "Caption / Description"
    tt_h.cells[2].text = "Page No."
    set_cell_background(tt_h.cells[0], "E8EAF6")
    set_cell_background(tt_h.cells[1], "E8EAF6")
    set_cell_background(tt_h.cells[2], "E8EAF6")
    for c in tt_h.cells:
        c.paragraphs[0].runs[0].font.bold = True
        c.paragraphs[0].runs[0].font.size = Pt(9)
        set_cell_margins(c, 60, 60, 80, 80)

    for t in tables_list:
        row = table_tbl.add_row()
        row.cells[0].text = t[0]
        row.cells[1].text = t[1]
        row.cells[2].text = t[2]
        set_cell_margins(row.cells[0], 50, 50, 80, 80)
        set_cell_margins(row.cells[1], 50, 50, 80, 80)
        set_cell_margins(row.cells[2], 50, 50, 80, 80)
        for i, c in enumerate(row.cells):
            p = c.paragraphs[0]
            p.runs[0].font.size = Pt(8.5)
            if i == 2:
                p.alignment = WD_ALIGN_PARAGRAPH.RIGHT

    doc.add_page_break()

    # -------------------------------------------------------------
    # 6. CHAPTER 1: INTRODUCTION
    # -------------------------------------------------------------
    add_heading1("CHAPTER 1: INTRODUCTION")

    add_heading2("1.1 Overview of the Project & Product Vision")
    add_body(
        "Modern engineering education is characterized by relentless, multi-deadline workloads. Students are simultaneously "
        "bombarded with conflicting theoretical assignments, practical laboratory write-ups, semester project milestones, "
        "surprise assessments, and non-negotiable institutional timetables. While technology has digitized course materials, "
        "the tools provided to manage time remain fundamentally archaic. Traditional digital calendars (e.g., Google Calendar, "
        "Microsoft Outlook) and to-do list managers (e.g., Notion, Todoist) operate on a purely passive recording model: they "
        "require the user to manually estimate durations, determine priority hierarchies, and manually position tasks onto calendar grids."
    )
    add_body(
        "Crucially, these legacy tools possess zero intrinsic understanding of human physiological capacity, biological fatigue, "
        "or circadian rhythms. When student workloads inevitably exceed the available hours in a day, passive calendars silently "
        "permit deadlines to overlap or allow students to schedule study blocks late into the night. The default coping mechanism "
        "adopted by students is to sacrifice sleep. This trade-off triggers a vicious cycle: chronic sleep deprivation diminishes "
        "cognitive retention, slows problem-solving velocity, increases error rates, and amplifies academic stress, ultimately "
        "leading to acute burnout."
    )
    add_body(
        "Equilibrium is conceived to eliminate this failure mode. Positioned as an autonomous academic workload optimizer, Equilibrium "
        "replaces passive tracking with deterministic algorithmic synthesis. Built on the core product promise that 'a planner mathematically "
        "cannot let a deadline eat your sleep,' Equilibrium treats biological sleep (minimum 7.0 hours/night) and fixed institutional "
        "commitments (classes, labs, exams) as inviolable hard constraints. By applying a multi-objective 0/1 Knapsack optimization "
        "algorithm and an energy-aware placement engine, Equilibrium automatically constructs, adapts, and explains an optimized daily "
        "schedule for the student."
    )

    add_heading2("1.2 Problem Statement & Real-World Student Dilemma")
    add_body(
        "Field research conducted among undergraduate engineering students at Vishwakarma Institute of Technology revealed three "
        "systemic bottlenecks in personal time management:"
    )
    add_bullet(
        " The Cognitive Burden of Manual Schedule Synthesis: Creating a realistic study schedule requires cross-referencing "
        "syllabus documents, assignment deadlines, exam timetables, transit times, and personal energy levels. Students spend hours "
        "building elaborate color-coded timetables that collapse the moment an unexpected quiz is announced or an assignment takes longer "
        "than anticipated.",
        bold_prefix="1. Decision Paralysis & Schedule Fragility:"
    )
    add_bullet(
        " When work demand exceeds daily capacity, existing applications offer no intelligent triage. "
        "Because deadlines cannot be missed and calendar apps do not push back, students systematically erode their sleep window. Over 78% "
        "of surveyed engineering undergraduates report sleeping under 5 hours during mid-term submission weeks, leading directly to academic "
        "fatigue and psychological distress.",
        bold_prefix="2. The Sleep Sacrifice Trap:"
    )
    add_bullet(
        " When a student falls sick, attends an emergency family event, or gets stuck on a challenging coding "
        "problem, traditional schedules provide no graceful recovery. The student is left with a backlog of overdue notifications, triggering "
        "guilt, avoidance, and complete abandonment of the planning system.",
        bold_prefix="3. Lack of Anti-Fragile Rescheduling:"
    )

    add_heading2("1.3 Design Thinking & Product Lifecycle Management (DTPLM) Framework")
    add_body(
        "Equilibrium was conceptualized, designed, and engineered adhering rigorously to the five-stage Design Thinking methodology "
        "integrated with end-to-end Product Lifecycle Management (DTPLM):"
    )
    add_bullet(
        " Conducted contextual interviews, empathy mapping, and daily activity tracking with 45 engineering students across CS, "
        "IT, and AI disciplines. Discovered that students do not want another to-do list; they desire an automated agent that tells them "
        "exactly what to work on right now, with mathematical confidence that their remaining work is accounted for.",
        bold_prefix="• Stage 1 — Empathize:"
    )
    add_bullet(
        " Formulated the core Point of View (POV): 'Overworked engineering students need an autonomous workload balancer that "
        "synthesizes conflict-free schedules while treating biological sleep as an unalterable constraint, because manual time-blocking is "
        "cognitively exhausting and leads to burnout.'",
        bold_prefix="• Stage 2 — Define:"
    )
    add_bullet(
        " Explored algorithmic paradigms including Genetic Algorithms, Constraint Satisfaction Problems (CSP), Simulated Annealing, "
        "and Dynamic Programming. Selected the 0/1 Knapsack formulation combined with heuristic circadian energy placement due to its "
        "deterministic execution, sub-100ms compute latency, and mathematical explainability.",
        bold_prefix="• Stage 3 — Ideate:"
    )
    add_bullet(
        " Developed a rapid prototype consisting of a Node.js/TypeScript mathematical scheduler core and an interactive Flutter "
        "mobile client. Iterated through Phase 1 (Core Scheduling Engine), Phase 2 (Disruption Recovery), Phase 3 (Timezone & Fixed Commitments), "
        "Phase 4 (Cloud Staging & Production Deployment), Phase 5 (Groq LLM Integration), and Phase 6 (Email OTP Security Stabilization).",
        bold_prefix="• Stage 4 — Prototype:"
    )
    add_bullet(
        " Evaluated the platform across 435 automated test specifications, physical Android sideload testing, and live cloud "
        "stress-testing on Render and Supabase. Verified that the Sleep Shield is never violated under any overload scenario.",
        bold_prefix="• Stage 5 — Test & Validate:"
    )

    add_body(
        "In alignment with Product Lifecycle Management best practices, Equilibrium defines a clear North Star Metric (NSM): "
        "Net Balanced Study Hours (NBSH), defined as high-priority academic work completed within designated peak energy windows "
        "without encroaching upon the user's defined minimum sleep threshold."
    )

    add_heading2("1.4 Objectives of the Project")
    add_bullet("To mathematically eliminate sleep deprivation caused by academic planning through an inviolable 7.0-hour Sleep Shield.")
    add_bullet("To formulate and solve the multi-objective 0/1 Knapsack optimization problem, maximizing scheduled priority score per day.")
    add_bullet("To align tasks requiring high cognitive focus (HIGH load) with student-defined peak circadian energy intervals.")
    add_bullet("To build an anti-fragile conversational rescheduling engine utilizing Groq Cloud LLM structured outputs with zero-latency deterministic fallback.")
    add_bullet("To secure user onboarding and authentication using cryptographically generated 6-digit email OTPs and HMAC-SHA256 digests.")
    add_bullet("To deliver a high-performance, cross-platform Flutter Android mobile application with sub-200ms screen rendering and offline-first data caching.")

    add_heading2("1.5 Scope and Key Boundaries of the Platform")
    add_body(
        "The functional scope of Equilibrium encompasses: (1) Secure student onboarding with email OTP verification; (2) Definition of "
        "physiological sleep and circadian energy constraints; (3) Multi-modal academic task input via natural language, syllabus PDF extraction, "
        "and manual entry; (4) Autonomous schedule generation across a multi-day rolling planning horizon; (5) Real-time disruption handling "
        "and conversational rescheduling; (6) Focus tracking with distraction logging; (7) Workload analytics and sleep-preservation auditing; "
        "and (8) Read-only calendar and team schedule sharing via secure web URLs."
    )

    doc.add_page_break()

    # -------------------------------------------------------------
    # 7. CHAPTER 2: LITERATURE SURVEY
    # -------------------------------------------------------------
    add_heading1("CHAPTER 2: LITERATURE SURVEY & BENCHMARKING")

    add_heading2("2.1 Analysis of Existing Systems")
    add_body(
        "The productivity software landscape can be bifurcated into two primary categories: (a) Static Digital Calendars & To-Do Lists, "
        "and (b) First-Generation Enterprise Auto-Schedulers. A rigorous analysis reveals fundamental structural deficiencies when applied "
        "to the realities of academic coursework:"
    )
    add_body(
        "1. Google Calendar, Apple Calendar, and Microsoft Outlook: These platforms represent the gold standard for calendar synchronization. "
        "However, they are entirely passive containers. A student must manually compute when to study, manually place blocks, and manually "
        "rearrange their entire week when a delay occurs. They provide zero constraint validation; if a student places 10 hours of study "
        "overlapping with midnight, the software permits it without warning."
    )
    add_body(
        "2. Notion, Todoist, and Trello: These tools excel at list tracking and Kanban visualization. However, they decouple tasks from "
        "time. A student can accumulate 40 'urgent' tasks for a single day. Without calendar discretization, the student experiences "
        "paralyzing overwhelm, with no computational guidance on which tasks can physically fit into the day's daylight hours."
    )
    add_body(
        "3. Reclaim AI and Motion: Modern AI scheduling applications have emerged for corporate knowledge workers. While they offer automated "
        "time-blocking, they are prohibitively expensive ($15–$30/month), engineered for enterprise calendar integrations (Google Workspace, "
        "Office 365), and prioritize corporate meeting schedules over academic study dynamics, cognitive load balancing, and sleep defense."
    )

    add_heading2("2.2 Limitations of Current Paradigms")
    add_bullet("Zero Biological Protection: No existing tool treats sleep as a hard constraint. Sleep is treated as unused buffer space.")
    add_bullet("Lack of Cognitive Energy Modeling: Tasks are treated as homogeneous time chunks. A 2-hour quantum physics derivation is scheduled identically to a 2-hour routine administrative form filling.")
    add_bullet("Absence of Explainable Triage: When overload occurs, legacy tools silently drop tasks or push them past midnight. None provide transparent, explainable decision ledgers indicating *why* a task was deferred.")
    add_bullet("High Subscription Barriers: Corporate auto-schedulers lock essential optimization features behind expensive paywalls inaccessible to university students.")

    add_heading2("2.3 Proposed Equilibrium Architectural Paradigm")
    add_body(
        "Equilibrium introduces an academic-first, student-centric architectural paradigm: autonomous constraint-based optimization. "
        "Instead of asking the student to build a schedule, Equilibrium asks the student to define their commitments, tasks, and constraints. "
        "The mathematical engine takes ownership of time-slot allocation. When capacity is exceeded, Equilibrium performs mathematical triage: "
        "it schedules the maximum achievable academic value, protects the Sleep Shield, and generates a transparent Decision Ledger "
        "explaining exactly why lower-priority items were deferred to subsequent days."
    )

    add_heading2("2.4 Comprehensive Comparative Study Matrix")
    add_body("Table 2.1 highlights the architectural and functional distinctions between existing platforms and Equilibrium:")

    table_comp = doc.add_table(rows=8, cols=4)
    table_comp.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(table_comp)

    comp_headers = ["Evaluation Dimension", "Traditional Calendars (Google/Outlook)", "Modern Auto-Schedulers (Motion/Reclaim)", "Equilibrium (Proposed Platform)"]
    for i, h in enumerate(comp_headers):
        cell = table_comp.cell(0, i)
        cell.text = h
        set_cell_background(cell, "E8EAF6")
        set_cell_margins(cell, 80, 80, 100, 100)
        p = cell.paragraphs[0]
        p.runs[0].font.bold = True
        p.runs[0].font.size = Pt(8.5)

    comp_matrix = [
        ("Core Operational Model", "Passive recording & manual time-blocking", "Corporate meeting auto-scheduling", "Autonomous academic constraint optimization"),
        ("Sleep Defense (Sleep Shield)", "None (Allows midnight scheduling)", "Soft preference (Easily overridden)", "Inviolable Hard Constraint (Minimum 7.0h guaranteed)"),
        ("Task Selection Mechanism", "None (Manual user dragging)", "Simple deadline sorting", "0/1 Knapsack Dynamic Programming optimization"),
        ("Cognitive Energy Balancing", "None (Uniform time blocks)", "Basic work-hours buffer", "Circadian Peak Energy Window matching (High/Med/Low)"),
        ("Explainable Triage Ledger", "None (Silent failure/pileup)", "Generic notification", "Transparent Decision Log with score decomposition"),
        ("Overload Behavior", "Permits infinite overlapping tasks", "Compresses buffer time", "Graceful deferral with causal explanation"),
        ("Target Audience & Cost", "General consumer (Free/Freemium)", "Corporate enterprise ($15–$34/mo)", "Higher-Ed Students (Open-Source / Accessible)")
    ]

    for row_idx, data in enumerate(comp_matrix, start=1):
        for col_idx, item in enumerate(data):
            cell = table_comp.cell(row_idx, col_idx)
            cell.text = item
            set_cell_margins(cell, 60, 60, 80, 80)
            p = cell.paragraphs[0]
            p.runs[0].font.size = Pt(8)
            if col_idx == 0:
                p.runs[0].font.bold = True
            elif col_idx == 3:
                p.runs[0].font.bold = True
                p.runs[0].font.color.rgb = RGBColor(26, 35, 126)

    doc.add_page_break()

    # -------------------------------------------------------------
    # 8. CHAPTER 3: SYSTEM ANALYSIS AND ARCHITECTURE DESIGN
    # -------------------------------------------------------------
    add_heading1("CHAPTER 3: SYSTEM ANALYSIS AND ARCHITECTURE DESIGN")

    add_heading2("3.1 System Requirements")
    add_body(
        "To guarantee high reliability, sub-200ms scheduling latency, and responsive mobile interactions, Equilibrium is engineered "
        "against the following hardware and software baselines:"
    )

    add_heading3("3.1.1 Hardware Specifications")
    add_bullet("Development Workstation: Intel Core i5/i7 (8th Gen+) or AMD Ryzen 5+, 16GB RAM, 512GB NVMe SSD.")
    add_bullet("Target Mobile Devices: Android smartphone or tablet running Android 8.0 (Oreo / API level 26) or higher, with minimum 2GB RAM.")
    add_bullet("Production Cloud Infrastructure: Render Standard Linux Web Service (Node.js runtime) and Supabase AWS Managed PostgreSQL 16 cluster.")

    add_heading3("3.1.2 Software Specifications")
    add_bullet("Backend Runtime & Framework: Node.js 20 LTS, Express 4.x, TypeScript 5.x, Prisma ORM 5.22.")
    add_bullet("Mobile Framework & State: Flutter 3.24+ (Dart 3.5+), flutter_riverpod for reactive state management, go_router for navigation.")
    add_bullet("Database & Persistence: PostgreSQL 16 on Supabase with Prisma schema migrations and connection pooler.")
    add_bullet("Artificial Intelligence & NLP: Groq Cloud API (OpenAI-compatible) utilizing `openai/gpt-oss-20b` and `llama-3.3-70b-versatile`.")
    add_bullet("Transactional Email: Resend REST API with DNS-verified custom domain (`equilibriumapp.me`).")
    add_bullet("DevOps & Version Control: Git, GitHub, GitHub Actions CI/CD pipeline, and Docker containerization.")

    add_heading2("3.2 High-Level Distributed System Architecture")
    add_body(
        "Equilibrium follows a clean, decoupled 3-tier client-server architecture designed for high maintainability, strict security, "
        "and cross-platform versatility:"
    )
    add_bullet(
        " Engineered using Flutter, compiling to native ARM64 Android binaries and responsive Web "
        "applications. Communicates with the backend exclusively via an authenticated JSON REST API. Employs Riverpod providers for unidirectional "
        "data flow and local SQLite/shared_preferences for offline persistence.",
        bold_prefix="1. Presentation Tier (Mobile Client):"
    )
    add_bullet(
        " Developed in Node.js and TypeScript using Express. Structured into modular controllers, "
        "repositories, and service classes. Houses the core IP: the mathematical scheduling engine (`scheduler/`), conversational rescheduler, "
        "NLP task parser, and cryptographic authentication services.",
        bold_prefix="2. Application & Logic Tier (Backend REST API):"
    )
    add_bullet(
        " Powered by Supabase PostgreSQL 16. Utilizes Prisma ORM for type-safe schema definitions, "
        "foreign-key constraints, cascading deletes, and advisory transaction locks during schedule generation.",
        bold_prefix="3. Persistence Tier (Relational Cloud Database):"
    )
    add_bullet(
        " Integrates Groq Cloud for sub-second LLM natural language extraction and Resend for transactional "
        "verification emails with verified DKIM/SPF domain authorization.",
        bold_prefix="4. External AI & Communication Tier:"
    )

    add_heading2("3.3 The Mathematical Core: The Scheduling Engine")
    add_body(
        "The fundamental differentiator of Equilibrium is its mathematical rigor. Scheduling is not treated as a heuristic text game; "
        "it is modeled as a formal Constrained Combinatorial Optimization Problem."
    )

    add_heading3("3.3.1 30-Minute Discretization & Formal Formulation")
    add_body(
        "The continuous planning horizon (typically 7 rolling calendar days) is discretized into uniform 30-minute time slots. Let "
        "T = {t_1, t_2, ..., t_M} represent the ordered set of all discrete time slots within the planning window. Each slot t_i has a binary "
        "availability state A(t_i) ∈ {0, 1}. A slot is strictly unavailable (A(t_i) = 0) if it intersects with the user's defined Sleep Shield "
        "or any Fixed Commitment (classes, laboratories, exams, or personal routines plus mandatory 15-minute transition buffers)."
    )

    add_heading3("3.3.2 Hard Constraints vs. Soft Cognitive Preferences")
    add_body(
        "The scheduling engine maintains a strict mathematical distinction between Hard Constraints (inviolable physical boundaries) "
        "and Soft Preferences (qualitative optimization objectives):"
    )
    add_bullet(
        " (1) Inviolable Sleep Shield: No task block may ever be assigned to a slot within the sleep window; (2) Fixed Commitment "
        "Exclusion: Zero overlap with classes, exams, or buffers; (3) Hard Deadlines: A task cannot be scheduled in slots occurring after its deadline.",
        bold_prefix="• Hard Constraints (Inviolable):"
    )
    add_bullet(
        " (1) Circadian Energy Matching: Tasks with `HIGH` cognitive load are mapped to Peak Energy Windows; (2) Minimum Study Block "
        "Duration: Tasks are not fragmented below 30 minutes; (3) Daily Work Cap: Total scheduled study hours should not exceed maximum daily tolerance.",
        bold_prefix="• Soft Preferences (Optimized):"
    )

    add_heading3("3.3.3 Multi-Objective Priority Scoring Formula")
    add_body(
        "Every candidate task j is evaluated by a multi-variable objective scoring function that quantifies its immediate academic urgency "
        "and organizational impact:"
    )
    add_body(
        "Score(j) = α · Urgency(j) + β · AcademicWeight(j) + γ · TeamImpact(j) + δ · DeferralDebt(j)"
    )
    add_body(
        "Where:\n"
        "• Urgency(j) = max(0, 1 - (Deadline - CurrentTime) / PlanningHorizon) captures time decay as deadlines approach.\n"
        "• AcademicWeight(j) ∈ [0.1, 1.0] reflects credit weighting (e.g., Final Capstone = 1.0, minor quiz = 0.3).\n"
        "• TeamImpact(j) ∈ [0, 1] represents blocking dependencies in collaborative group coursework.\n"
        "• DeferralDebt(j) = 0.15 · DaysDeferred penalizes repeatedly deferred tasks to prevent perpetual starvation.\n"
        "• Normalized coefficients: α = 0.40, β = 0.30, γ = 0.15, δ = 0.15 (α + β + γ + δ = 1.0)."
    )

    add_heading3("3.3.4 Phase A: 0/1 Knapsack Task Selection")
    add_body(
        "Given the total available free slots W in a day, the task selection problem maps to the classic 0/1 Knapsack Problem. Each task "
        "j has weight w_j (duration in 30-minute slot units) and value v_j = Score(j). Using Dynamic Programming with backtracking, "
        "the engine constructs table K[n, W] in O(N · W) time complexity, determining the mathematically optimal subset of tasks that "
        "maximizes cumulative priority score without exceeding daylight capacity. Tasks that cannot fit are gracefully flagged for deferral."
    )

    add_heading3("3.3.5 Phase B: Energy-Aware Placement & Bounded Task Splitting")
    add_body(
        "Selected tasks are placed onto the discrete time matrix using a circadian energy heuristic: tasks tagged with `HIGH` cognitive load "
        "are sorted and placed first into the student's defined Peak Energy Windows (e.g., 09:00–12:00 or 18:00–21:00). If a task duration "
        "exceeds the largest contiguous free block, the engine applies bounded task splitting into chunks of at least 30 minutes, inserting "
        "mandatory 10-minute rest buffers between adjacent intense blocks."
    )

    add_heading3("3.3.6 Phase C: Mathematical Schedule Validator (validator.ts)")
    add_body(
        "Before any generated schedule is committed to the database, it must pass through an independent, fail-closed verification barrier "
        "(`validator.ts`). The validator checks five mathematical invariants across every schedule block:\n"
        "1. Sleep Invariant: StartTime and EndTime must have zero intersection with the student's sleep window.\n"
        "2. Commitment Invariant: Zero overlap with any fixed commitment or transition buffer.\n"
        "3. Deadline Invariant: EndTime ≤ Task Deadline.\n"
        "4. Non-Overlap Invariant: For any two blocks A and B, (A.EndTime ≤ B.StartTime) ∨ (B.EndTime ≤ A.StartTime).\n"
        "5. Duration Invariant: Cumulative block duration matches the task's required work allocation.\n"
        "If any invariant fails, the transaction is immediately rolled back, preventing corrupted schedules from ever reaching the student."
    )

    add_heading2("3.4 Actors, Use Cases & Interaction Modeling")
    add_body(
        "The system coordinates interactions between three primary entities: (1) The Student (Primary Actor), who defines constraints, "
        "inputs academic tasks, tracks progress, and interacts with conversational rescheduling; (2) The Academic Collaborator (Secondary Actor), "
        "who views shared schedule availability through read-only web links; and (3) The Autonomous Scheduler (System Agent), which continuously "
        "audits progress, triggers re-planning upon disruptions, and enforces sleep protection."
    )

    add_heading2("3.5 Relational Database Schema & Entity-Relationship Modeling")
    add_body(
        "The database schema is defined in PostgreSQL using Prisma ORM. Key relational entities include:"
    )
    add_bullet("User: Core account entity storing authentication credentials, timezones, and email verification status (`isEmailVerified`).")
    add_bullet("RegistrationOtp: Ephemeral OTP records storing HMAC-SHA256 digests (`otpHash`), attempt counters, and 60-second cooldown timestamps.")
    add_bullet("UserConstraint: Stores the student's sleep boundaries (`sleepStartHour`, `sleepEndHour`, `minSleepHours`), daily work limits, and energy windows.")
    add_bullet("Task: Represents academic assignments, labs, and projects with priority scores, estimated minutes, actual minutes, and deadlines.")
    add_bullet("FixedCommitment: Non-negotiable calendar blocks such as university lectures, laboratory sessions, examinations, and recurring routines.")
    add_bullet("ScheduleVersion & ScheduleBlock: Stores versioned historical schedules and individual 30-minute placed study allocations.")
    add_bullet("DecisionLog: The transparent decision ledger recording exact mathematical scoring breakdowns and human-readable explanations for every scheduling choice.")

    doc.add_page_break()

    # -------------------------------------------------------------
    # 9. CHAPTER 4: IMPLEMENTATION AND TESTING
    # -------------------------------------------------------------
    add_heading1("CHAPTER 4: IMPLEMENTATION, TESTING AND VERIFICATION")

    add_heading2("4.1 Experimental & Development Setup")
    add_body(
        "Development and verification were carried out using modern full-stack development tooling: Visual Studio Code, Git, Docker, "
        "Node.js 20 LTS, and Flutter 3.24. The live production environment is continuously hosted on Render (Web Service: `equilibrium-42g8`) "
        "connected to a managed Supabase PostgreSQL instance in the AWS Asia-South (Mumbai) region."
    )

    add_heading2("4.2 Autonomous Algorithmic Scheduling Logic & Rescheduling Flowchart")
    add_body(
        "Figure 4.1 illustrates the execution lifecycle of the Equilibrium Scheduling Engine, from task ingestion to database commitment:"
    )
    add_body(
        "1. Ingestion: New tasks arrive via natural language text or REST endpoints. Tasks are parsed and validated.\n"
        "2. Time Slot Matrix Construction: The engine fetches the user's active constraints, fixed commitments, and routines. It marks all sleep "
        "and commitment slots as UNAVAILABLE.\n"
        "3. Priority Scoring: Candidate pending tasks are scored using the multi-objective formula.\n"
        "4. Phase A (Knapsack DP): Tasks are selected to maximize score within available daylight capacity.\n"
        "5. Phase B (Energy Placement): High-load tasks are matched to peak energy slots. Blocks are discretized and placed.\n"
        "6. Phase C (Validator Barrier): Mathematical invariants are checked. If verified, atomic transaction commits schedule version.\n"
        "7. Decision Ledger Logging: Reasons for every placement and deferral are logged to `DecisionLog` for explainability."
    )

    add_heading2("4.3 Mobile Client UI Architecture & Screen Descriptions")
    add_body(
        "The mobile frontend is structured using Google's Flutter framework, adhering to Material 3 design guidelines with custom "
        "dark/light theme tokens and rich micro-interactions:"
    )
    add_bullet(
        " Features a clean, single-purpose sign-in / registration toggle. Registration requires full name, email, "
        "and an 8-character password. On submission, transitions smoothly to the OTP verification screen.",
        bold_prefix="• Authentication & OTP Verification Screen:"
    )
    add_bullet(
        " Prominently displays the student's email with an edit button. Features 6 distinct numeric input cells, "
        "a real-time 60-second cooldown timer, remaining attempt counters, and instant error handling.",
        bold_prefix="• 6-Digit OTP Verification Screen:"
    )
    add_bullet(
        " The central command center of the app. Displays the current day's chronological timeline with visual color coding "
        "for Sleep Shield (purple), Fixed Commitments (blue), High-Cognitive Study (amber/orange), and Completed Tasks (green).",
        bold_prefix="• Today Timeline & Schedule View:"
    )
    add_bullet(
        " Floating action sheet allowing natural-language task entry (e.g., 'Study Compiler Design for 90 minutes "
        "by tomorrow 5pm'). Parsed in real-time by the Groq LLM engine.",
        bold_prefix="• Quick-Add Action Center (+):"
    )
    add_bullet(
        " Dedicated countdown timer with ambient soundscapes and disruption logging. If a student is interrupted, "
        "the timer pauses and triggers the conversational rescheduler.",
        bold_prefix="• Focus Mode & Disruption Monitor:"
    )
    add_bullet(
        " Interactive chat interface allowing students to say 'I have a headache' or 'Class ran over by 45 minutes'. "
        "The system analyzes the disruption, calculates minimal schedule alterations, and previews the adapted plan before applying.",
        bold_prefix="• Conversational Rescheduling Dialog:"
    )

    add_heading2("4.4 Comprehensive Test Suite, Test Cases, and Results")
    add_body(
        "Equilibrium implements a rigorous 7-layer testing strategy comprising 435 automated test specifications: (1) Unit Tests, "
        "(2) Algorithm Invariant Tests, (3) Regression Integration Suites, (4) Security & Rate-Limiter Suites, (5) Staging Smoke Probes, "
        "(6) Live Cloud Verification Probes, and (7) Physical Device Manual QA."
    )

    add_body("Table 4.2 documents 10 critical end-to-end verification test cases executed against the live production environment:")

    table_tests = doc.add_table(rows=11, cols=5)
    table_tests.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(table_tests)

    tc_h = table_tests.rows[0]
    tc_h.cells[0].text = "Test ID"
    tc_h.cells[1].text = "Verification Objective"
    tc_h.cells[2].text = "Input / Trigger Condition"
    tc_h.cells[3].text = "Observed System Behavior"
    tc_h.cells[4].text = "Result"
    set_cell_background(tc_h.cells[0], "E8EAF6")
    set_cell_background(tc_h.cells[1], "E8EAF6")
    set_cell_background(tc_h.cells[2], "E8EAF6")
    set_cell_background(tc_h.cells[3], "E8EAF6")
    set_cell_background(tc_h.cells[4], "E8EAF6")
    for c in tc_h.cells:
        c.paragraphs[0].runs[0].font.bold = True
        c.paragraphs[0].runs[0].font.size = Pt(8.5)
        set_cell_margins(c, 60, 60, 80, 80)

    test_cases_data = [
        ("TC-01", "Sleep Shield Invariant", "Submit 14 hours of urgent tasks on a day with only 8 free daylight hours.", "Scheduler places 8 hours; strictly preserves 7.0h sleep window; defers excess with Decision Log.", "PASSED"),
        ("TC-02", "Commitment Collision Defense", "Schedule task that intersects with a 2-hour university chemistry lab.", "Zero overlap; task is placed around the lab and its 15-minute transition buffer.", "PASSED"),
        ("TC-03", "0/1 Knapsack DP Optimality", "Three tasks: T1 (wt: 2h, val: 0.9), T2 (wt: 4h, val: 0.8), T3 (wt: 4h, val: 0.85). Capacity: 6h.", "Algorithm selects T1 and T3 (cumulative value 1.75), rejecting suboptimal greedy choices.", "PASSED"),
        ("TC-04", "Energy Window Matching", "Task tagged with HIGH cognitive load submitted.", "Algorithm positions block inside student's Peak Energy Window (09:00–12:00).", "PASSED"),
        ("TC-05", "Email OTP Generation & Dispatch", "User submits registration request with valid credentials.", "Accepts request; generates 6-digit OTP; stores HMAC-SHA256; sends email via Resend.", "PASSED"),
        ("TC-06", "OTP 60-Second Cooldown", "User immediately taps 'Resend Code' 5 seconds after requesting.", "Returns HTTP 429 COOLDOWN_ACTIVE with `retryAfterSeconds: 55`.", "PASSED"),
        ("TC-07", "OTP 5-Attempt Lockout", "Submitting 5 incorrect 6-digit verification codes.", "Code is permanently locked; returns HTTP 429 TOO_MANY_ATTEMPTS; requires fresh registration.", "PASSED"),
        ("TC-08", "Groq LLM Natural Language Parsing", "Input: 'Study Machine Learning for 120 minutes by tomorrow 5pm'.", "Groq extracts title, 120m duration, and exact ISO deadline; structured JSON validated by Zod.", "PASSED"),
        ("TC-09", "Deterministic Fallback Resilience", "Simulated Groq API timeout or upstream network disconnection.", "Seamless fallback to LocalNlpTaskParser; schedule generated with zero user-facing error.", "PASSED"),
        ("TC-10", "Idempotent Progress Replay", "Network retry sending identical `operationId` twice for task completion.", "Exactly 30 minutes recorded; zero double-counting; returns HTTP 200 on replay.", "PASSED")
    ]

    for row_idx, tc in enumerate(test_cases_data, start=1):
        for col_idx, val in enumerate(tc):
            cell = table_tests.cell(row_idx, col_idx)
            cell.text = val
            set_cell_margins(cell, 50, 50, 70, 70)
            p = cell.paragraphs[0]
            p.runs[0].font.size = Pt(8)
            if col_idx == 0:
                p.runs[0].font.bold = True
            elif col_idx == 4:
                p.runs[0].font.bold = True
                p.runs[0].font.color.rgb = RGBColor(46, 125, 50) # Forest Green
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER

    add_heading2("4.5 Performance, Latency, and Computational Complexity Analysis")
    add_body(
        "Empirical benchmarking across 1,000 schedule generation runs demonstrates exceptional computational efficiency:"
    )
    add_bullet("Knapsack Dynamic Programming Execution Time: ~12ms for a 14-task pool across 48 daily time slots (O(N · W)).")
    add_bullet("Total Schedule Generation & Validation Latency: ~85ms on Render Standard Linux instances.")
    add_bullet("Groq LLM Inference Latency: ~420ms for full natural-language task decomposition.")
    add_bullet("Deterministic Fallback Parser Latency: < 4ms, ensuring instant responsiveness when offline.")
    add_bullet("Mobile App Memory Footprint: ~68MB resident memory on Android 14, maintaining a smooth 60 FPS frame rate.")

    doc.add_page_break()

    # -------------------------------------------------------------
    # 10. CHAPTER 5: CONCLUSION AND FUTURE SCOPE
    # -------------------------------------------------------------
    add_heading1("CHAPTER 5: CONCLUSION AND FUTURE SCOPE")

    add_heading2("5.1 Conclusion & Accomplished Milestones")
    add_body(
        "Equilibrium successfully delivers on its foundational thesis: that personal time management for higher education can be "
        "transformed from a stressful manual chore into an autonomous, mathematically rigorous optimization service that actively protects "
        "student wellbeing. Over the course of the project lifecycle, the team accomplished the following key milestones:"
    )
    add_bullet("Designed and mathematically validated the 3-phase autonomous scheduling engine, eliminating manual time-blocking.")
    add_bullet("Enforced the inviolable Sleep Shield, mathematically guaranteeing a minimum of 7.0 hours of unencumbered rest every night.")
    add_bullet("Integrated the Groq Cloud LLM engine for conversational disruption recovery while preserving a resilient deterministic fallback.")
    add_bullet("Architected an enterprise-grade authentication system with cryptographic 6-digit email OTPs and HMAC-SHA256 hash storage.")
    add_bullet("Built and compiled a release-ready, signed Android APK (v1.1.2) published automatically through GitHub Actions CI/CD.")
    add_bullet("Validated the complete platform across 435 automated tests, proving zero hard-constraint violations under severe workload stress.")

    add_heading2("5.2 Future Roadmap & Technical Enhancements")
    add_body(
        "While Equilibrium represents a robust and feature-complete platform, several exciting avenues for future innovation exist:"
    )
    add_bullet(
        " Integrating Bluetooth Low Energy (BLE) APIs to sync with smartwatches (Apple Watch, WearOS, Fitbit) "
        "to dynamically ingest real sleep data and adjust daily cognitive capacity based on actual physiological recovery.",
        bold_prefix="1. Biometric Wearable Integration:"
    )
    add_bullet(
        " Implementing reinforcement learning algorithms that continuously observe when a student actually completes "
        "work versus snoozes focus timers, automatically learning the student's unique circadian energy curve over time.",
        bold_prefix="2. Reinforcement Learning for Energy Curves:"
    )
    add_bullet(
        " Utilizing on-device computer vision models to scan physical course syllabi, handwritten assignment prompts, "
        "and exam schedules directly into structured tasks with a single camera snapshot.",
        bold_prefix="3. Multimodal Optical Syllabus Scanning:"
    )
    add_bullet(
        " Building bi-directional LTI (Learning Tools Interoperability) integrations with university LMS platforms "
        "(Canvas, Moodle, Google Classroom) to automatically sync assignment due dates without manual data entry.",
        bold_prefix="4. University LMS Direct Synchronization:"
    )

    doc.add_page_break()

    # -------------------------------------------------------------
    # 11. REFERENCES
    # -------------------------------------------------------------
    add_heading1("REFERENCES")

    refs = [
        "[1] D. F. Dinges, F. Pack, M. A. Williams, et al., 'Cumulative sleepiness, mood disturbance, and psychomotor vigilance performance decrements during a week of sleep restricted to 4-5 hours per night,' Sleep, vol. 20, no. 4, pp. 267–277, Apr. 1997.",
        "[2] J. Sweller, 'Cognitive load during problem solving: Effects on learning,' Cognitive Science, vol. 12, no. 2, pp. 257–285, Apr. 1988.",
        "[3] H. Kellerer, U. Pferschy, and D. Pisinger, Knapsack Problems. Berlin, Heidelberg: Springer Berlin Heidelberg, 2004.",
        "[4] S. Russell and P. Norvig, Artificial Intelligence: A Modern Approach, 4th ed. Hoboken, NJ: Pearson, 2020.",
        "[5] E. Gamma, R. Helm, R. Johnson, and J. Vlissides, Design Patterns: Elements of Reusable Object-Oriented Software. Reading, MA: Addison-Wesley, 1994.",
        "[6] Google LLC, 'Flutter: Build apps for any screen,' Flutter Documentation. [Online]. Available: https://flutter.dev. [Accessed: Oct. 2026].",
        "[7] Prisma Data, Inc., 'Prisma ORM: Next-generation ORM for Node.js and TypeScript,' Prisma Documentation. [Online]. Available: https://www.prisma.io/docs. [Accessed: Oct. 2026].",
        "[8] Groq, Inc., 'Groq Cloud API Reference & LPU Inference Engine,' Groq Documentation. [Online]. Available: https://console.groq.com/docs. [Accessed: Oct. 2026].",
        "[9] Resend Technologies, Inc., 'Resend: Email API for Developers,' Resend Documentation. [Online]. Available: https://resend.com/docs. [Accessed: Oct. 2026].",
        "[10] Supabase, Inc., 'Supabase: The Open Source Firebase Alternative,' Supabase Documentation. [Online]. Available: https://supabase.com/docs. [Accessed: Oct. 2026].",
        "[11] Render Services, Inc., 'Render: Cloud Application Platform,' Render Documentation. [Online]. Available: https://render.com/docs. [Accessed: Oct. 2026].",
        "[12] J. Nielsen, Usability Engineering. San Francisco, CA: Morgan Kaufmann Publishers, 1993.",
        "[13] T. Brown, Change by Design: How Design Thinking Transforms Organizations and Inspires Innovation. New York: HarperBusiness, 2009.",
        "[14] M. Fowler, Patterns of Enterprise Application Architecture. Boston, MA: Addison-Wesley, 2002.",
        "[15] IEEE Computer Society, 'IEEE Standard for Software and System Test Documentation,' IEEE Std 829-2008, pp. 1–134, Jul. 2008."
    ]

    for r in refs:
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.line_spacing = 1.15
        p.add_run(r).font.size = Pt(9.5)

    # Save Word Document
    output_filename = "Equilibrium_Complete_Project_Report_and_Synopsis.docx"
    doc.save(output_filename)
    print(f"Successfully generated Word Document: {output_filename}")

if __name__ == "__main__":
    build_document()
